import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../../models/calendar/calendar_week.dart';

/// 校历 / 教学日历解析。
abstract final class CalendarParser {
  /// 校历 PDF 地址藏在页面 script 的数组里（旧 parseCalendarUrlFromRawHtml）。
  static String parseSchoolCalendarPdfUrl(String html) {
    final script = html_parser
        .parse(html)
        .querySelectorAll('script')
        .map((e) => e.text)
        .join();
    final start = script.indexOf('[');
    final end = script.indexOf(']');
    if (start < 0 || end < 0 || end <= start) {
      throw const FormatException('校历页面里找不到地址数组');
    }
    final listString = script.substring(start, end + 1);
    final urlIndex = listString.indexOf('url:');
    final startQuote = listString.indexOf('"', urlIndex);
    final endQuote = listString.indexOf('"', startQuote + 1);
    if (urlIndex < 0 || startQuote < 0 || endQuote < 0) {
      throw const FormatException('校历地址格式变了');
    }
    return 'https://bksy.bjtu.edu.cn${listString.substring(startQuote + 1, endQuote)}';
  }

  /// 教学日历：iframe src 的后 5 段拼到静态资源前缀上（旧 getTeachingCalendarUrl）。
  static String parseTeachingCalendarPdfUrl(String iframeSrc) {
    final segments = iframeSrc.split('/');
    final key = segments.length > 5
        ? segments.sublist(segments.length - 5)
        : segments;
    return 'http://123.121.147.7:1936/kk/rp/${key.join('/')}';
  }

  /// 第二学期（春季）在 aa 系统 `zc` 编号里的续编偏移：春季 18 周后从 19 起。
  /// 校历把后半段标成「第N周」（没有「教学」二字），要加上这个偏移。
  static const int springWeeks = 18;

  /// 校历页面（bksy SemesterTranPage）里所有学期 -> 教学周列表。
  ///
  /// 页面上那 29 张周历表是 JS 从隐藏字段 `hidJson` 动态渲染的，静态 HTML 里没有，
  /// 所以必须解这个字段：
  /// `hidJson` 是 URL 编码的 JSON 数组，每项 `{"Id":49,"Json":[{"DT":"/Date(毫秒+0800)/",
  /// "Week":"第1教学周",...},...]}`；学期标题来自同页的 `hidTitle_` 字段。
  ///
  /// **假期周靠这里天然被跳过**：假期那行的 `Week` 不是「第N教学周」（是「休」之类），
  /// 匹配不上就跳过，于是「第3周→9/21、第4周→10/12」中间自然空出两周 ——
  /// 补齐空周由 [TeachingCalendar.fromWeeks] 负责。
  ///
  /// 尽力而为：任何一步失败都返回空表，不抛异常（日期只是显示参考，拿不到不该阻断同步）。
  static Map<String, TeachingCalendar> parseAcademicWeeks(String html) {
    final inputs = _hiddenInputs(html);
    final payload = inputs.entries
        .where((e) => e.key.toLowerCase() == 'hidjson')
        .map((e) => e.value)
        .firstOrNull;
    if (payload == null) return const {};

    // value 可能带 HTML 转义（&quot; 等）和 ASP.NET UrlEncode（空格是 +）。
    final decoded = _decode(
      payload.replaceAll('&quot;', '"').replaceAll('&#39;', "'"),
    );
    final Object? tree;
    try {
      tree = jsonDecode(decoded);
    } catch (_) {
      return const {};
    }
    if (tree is! List) return const {};

    final titles = <int, String>{};
    for (final entry in inputs.entries) {
      final match = RegExp(
        r'^hidTitle_(\d+)$',
        caseSensitive: false,
      ).firstMatch(entry.key);
      final id = match == null ? null : int.tryParse(match.group(1)!);
      if (id != null) titles[id] = entry.value;
    }

    final result = <String, TeachingCalendar>{};
    for (final item in tree) {
      if (item is! Map) continue;
      final id = int.tryParse('${item['Id']}');
      final title = id == null ? null : titles[id];
      final parsed = title == null ? null : _weeksOf(item['Json'], title);
      final calendar = parsed;
      if (calendar != null) result[calendar.label] = calendar;
    }
    return result;
  }

  /// 一项学期 -> 教学周。标题形如 `第一学期（2026-2027学年）`。
  static TeachingCalendar? _weeksOf(Object? rows, String title) {
    if (rows is! List) return null;
    final titleMatch = RegExp(
      r'第(一|二)学期\s*[（(]\s*(\d{4})-(\d{4})\s*学年\s*[)）]',
    ).firstMatch(title);
    if (titleMatch == null) return null;
    // 「二学期」= 春季段（学年秋→次年春），需要 +18 的 zc 偏移。
    final isSecond = titleMatch.group(1) == '二';
    final baseYear = int.tryParse(titleMatch.group(2)!);
    if (baseYear == null) return null;

    final weeks = <CalendarWeek>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final week = _weekNumber('${row['Week']}'.trim(), isSecond);
      // 非周次行（「休」「放假」…）就是假期周：不收，周数在这里天然不推进。
      if (week == null) continue;
      final monday = _mondayOf('${row['DT']}');
      if (monday == null) continue;
      weeks.add(CalendarWeek(teachingWeek: week, startDate: monday));
    }
    return TeachingCalendar.fromWeeks(
      weeks,
      label: '$baseYear-${baseYear + 1}-${isSecond ? 2 : 1}',
    );
  }

  /// `第3教学周` -> 3；春季后半段的 `第3周` -> 3 + 18；其它（假期行）-> null。
  static int? _weekNumber(String text, bool isSecond) {
    final teaching = RegExp(r'第(\d+)教学周').firstMatch(text);
    if (teaching != null) return int.tryParse(teaching.group(1)!);
    if (!isSecond) return null;
    final plain = RegExp(r'第(\d+)周').firstMatch(text);
    return plain == null ? null : int.tryParse(plain.group(1)!)! + springWeeks;
  }

  /// 微软 JSON 日期 `/Date(1700000000000+0800)/`：毫秒是 UTC 时间戳，
  /// 对应北京时间周一 00:00，所以 +8 小时后按 UTC 取日期就是那一周的周一。
  static DateTime? _mondayOf(String raw) {
    final millis = int.tryParse(
      RegExp(r'/Date\((\d+)').firstMatch(raw)?.group(1) ?? '',
    );
    if (millis == null) return null;
    final shifted = DateTime.fromMillisecondsSinceEpoch(
      millis + 8 * 60 * 60 * 1000,
      isUtc: true,
    );
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  /// 页面上所有 `<input>` 的 name/id -> value（未解码，解码留给调用方按需做）。
  static Map<String, String> _hiddenInputs(String html) {
    final result = <String, String>{};
    for (final match in RegExp(
      r'<input\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final tag = match.group(0)!;
      final name = RegExp(
        r"""\bname\s*=\s*['"]([^'"]*)['"]""",
        caseSensitive: false,
      ).firstMatch(tag)?.group(1);
      final id = RegExp(
        r"""\bid\s*=\s*['"]([^'"]*)['"]""",
        caseSensitive: false,
      ).firstMatch(tag)?.group(1);
      // 线上页面 hidJson 只有 name，hidTitle_<Id> 只有 id，所以两边都取。
      final key = (name ?? id)?.trim();
      if (key == null || key.isEmpty) continue;
      final value = RegExp(
        r"""\bvalue\s*=\s*"([^"]*)"|\bvalue\s*=\s*'([^']*)'""",
        caseSensitive: false,
      ).firstMatch(tag);
      if (value == null) continue;
      result[key] = value.group(1) ?? value.group(2) ?? '';
    }
    return result;
  }

  static String _decode(String value) {
    try {
      return Uri.decodeComponent(value.replaceAll('+', ' '));
    } catch (_) {
      return value;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
