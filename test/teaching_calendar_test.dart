import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/models/calendar/calendar_week.dart';
import 'package:bjtuselfserviceaio/data/remote/parsers/calendar_parser.dart';

/// 2026 秋：第 3 周从 9/21 开始，国庆空掉 9/28 与 10/5 两周，
/// 第 4 周从 10/12 开始 —— 与教务处校历（bksy）结构一致。
List<CalendarWeek> _nationalDayWeeks() => [
  for (var week = 1; week <= 3; week++)
    CalendarWeek(teachingWeek: week, startDate: DateTime(2026, 9, 7 + 7 * (week - 1))),
  for (var week = 4; week <= 8; week++)
    CalendarWeek(teachingWeek: week, startDate: DateTime(2026, 10, 12 + 7 * (week - 4))),
];

void main() {
  group('校历时间轴：假期周不推进周次', () {
    final calendar = TeachingCalendar.fromWeeks(_nationalDayWeeks(), label: '2026-2027-1')!;

    test('国庆那一周不是「第 4 周」，它是假期周', () {
      expect(calendar.weekOf(DateTime(2026, 9, 28)), isNull, reason: '9/28 开始是假期周');
      expect(calendar.weekOf(DateTime(2026, 10, 5)), isNull, reason: '10/5 那周也是假期周');
      expect(calendar.weekOf(DateTime(2026, 10, 1)), isNull);
    });

    test('假期前后周次连续：9/21 是第 3 周，10/12 是第 4 周', () {
      expect(calendar.weekOf(DateTime(2026, 9, 21)), 3);
      expect(calendar.weekOf(DateTime(2026, 9, 27)), 3);
      expect(calendar.weekOf(DateTime(2026, 10, 12)), 4);
    });

    test('时间轴按自然周排开，假期周占位', () {
      final mondays = calendar.slots.map((s) => s.monday).toList();
      expect(
        mondays,
        containsAllInOrder([DateTime(2026, 9, 21), DateTime(2026, 9, 28), DateTime(2026, 10, 5), DateTime(2026, 10, 12)]),
      );
      final holidays = calendar.slots.where((s) => s.isNonTeachingWeek).length;
      expect(holidays, 2, reason: '国庆空了两周');
    });

    test('周次 -> 周一：假期不会让后面的周整体后移', () {
      expect(calendar.mondayOfWeek(4), DateTime(2026, 10, 12));
      expect(calendar.mondayOfWeek(8), DateTime(2026, 11, 9));
    });

    test('没校历时退回 7 天除法（并明确它算不准）', () {
      // 同一个假期，纯除法会把 10/12 算成第 6 周 —— 这正是要避免的。
      expect(
        TeachingCalendar.fallbackWeekOf(
          firstWeekMonday: DateTime(2026, 9, 7),
          now: DateTime(2026, 10, 12),
        ),
        6,
      );
      expect(calendar.weekOf(DateTime(2026, 10, 12)), 4);
    });

    test('JSON 往返后假期周仍在', () {
      final restored = TeachingCalendar.fromJson(calendar.toJson())!;
      expect(restored.weekOf(DateTime(2026, 10, 5)), isNull);
      expect(restored.weekOf(DateTime(2026, 10, 12)), 4);
      expect(restored.label, '2026-2027-1');
    });
  });

  group('校历页面解析：hidJson', () {
    test('假期行（Week 不是「第N教学周」）被跳过，其余给出周次与周一日期', () {
      final html = _page([
        _semester(49, '第一学期（2026-2027学年）', [
          {'DT': '/Date(1788739200000+0800)/', 'Week': '第1教学周'},
          {'DT': '/Date(1789344000000+0800)/', 'Week': '第2教学周'},
          {'DT': '/Date(1789948800000+0800)/', 'Week': '休'},
          {'DT': '/Date(1790553600000+0800)/', 'Week': '第3教学周'},
        ]),
      ]);
      final parsed = CalendarParser.parseAcademicWeeks(html);
      expect(parsed.length, 1);
      final calendar = parsed['2026-2027-1']!;
      expect(calendar.slots.where((s) => s.teachingWeek != null).length, 3);
      expect(calendar.slots.length, 4, reason: '中间那一周补成假期周');
      expect(calendar.weekOf(DateTime(2026, 9, 21)), isNull, reason: '9/21 那一行是假期，被跳过');
      expect(calendar.weekOf(DateTime(2026, 9, 28)), 3, reason: '假期结束后周次继续第 3 周');
    });

    test('第二学期的夏季段「第N周」要加 18 偏移', () {
      final html = _page([
        _semester(50, '第二学期（2027-2028学年）', [
          {'DT': '/Date(1803859200000+0800)/', 'Week': '第1教学周'},
          {'DT': '/Date(1808697600000+0800)/', 'Week': '第1周'},
        ]),
      ]);
      final parsed = CalendarParser.parseAcademicWeeks(html);
      final calendar = parsed['2027-2028-2'];
      expect(calendar, isNotNull);
      expect(calendar!.slots.last.teachingWeek, 19);
    });

    test('页面结构不认识时返回空表，不抛异常', () {
      expect(CalendarParser.parseAcademicWeeks('<html>没有 hidJson</html>'), isEmpty);
      expect(CalendarParser.parseAcademicWeeks(''), isEmpty);
    });
  });
}

String _semester(int id, String title, List<Map<String, String>> rows) {
  final rowsJson = rows.map((r) => '{${r.entries.map((e) => '"${e.key}":"${e.value}"').join(',')}}').join(',');
  return '{"Id":$id,"Json":[$rowsJson]}';
}

String _page(List<String> semesters) {
  final hidJson = Uri.encodeQueryComponent('[${semesters.join(',')}]');
  return '<html><body>'
      '<input type="hidden" name="hidJson" value="$hidJson">'
      '<input type="hidden" id="hidTitle_49" value="第一学期（2026-2027学年）">'
      '<input type="hidden" id="hidTitle_50" value="第二学期（2027-2028学年）">'
      '</body></html>';
}
