import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../models/course/course_model.dart';
import '../../models/course/platform_course.dart';
import '../../models/course/schedule_position.dart';

/// HTML/JSON -> Course 模型。
///
/// 学校改版时只改这里，API 层和 Repository 不用动。
///
/// 课表有两个数据来源，可靠性差别很大：
/// 1. 教务（本科生院）HTML 课表页 —— 有格子位置、周次、教师、地点，**主来源**；
/// 2. 课程平台 JSON —— 只有课程名/教师/开课周次，**没有格子位置**，仅作兜底。
abstract final class CourseParser {
  // ---- 教务 HTML 课表页（主来源）----

  /// 解析课表表格。第一行是表头，跳过；每行 7 个 `td` 对应周一到周日。
  ///
  /// 端口与旧项目 `_parseCourseTable` 一致：格子下标 = `节次 * 8 + 星期`，
  /// 其中每行第一个位置是空位，真正的 7 天从下标 1 开始。
  static List<Course> parseScheduleHtml(
    String raw, {
    required bool isCurrentSemester,
  }) {
    final table = html_parser.parse(raw).querySelector('table');
    if (table == null) {
      return const [];
    }
    final courses = <Course>[];
    final rows = table.querySelectorAll('tr').skip(1).toList();
    for (final rowEntry in rows.asMap().entries) {
      final section = rowEntry.key + 1;
      if (section > SchedulePosition.sectionCount) {
        break;
      }
      final cells = rowEntry.value
          .querySelectorAll('td')
          .skip(1)
          .take(SchedulePosition.weekdayCount)
          .toList();
      for (final cellEntry in cells.asMap().entries) {
        final weekday = cellEntry.key + 1;
        for (final card in _cardsOf(cellEntry.value)) {
          final course = _parseCourseCard(
            card,
            locationIndex: SchedulePosition.locationIndex(
              section: section,
              weekday: weekday,
            ),
            isCurrentSemester: isCurrentSemester,
          );
          if (course != null) {
            courses.add(course);
          }
        }
      }
    }
    return courses;
  }

  /// 一个 `td` 里可能塞了多门课（上下午连堂、同一格不同课程）。
  /// 没有子节点时单元格本身就是一张课程卡。
  static List<Element> _cardsOf(Element cell) {
    final candidates = cell.children.isEmpty ? <Element>[cell] : cell.children;
    return candidates
        .where((child) => child.text.trim().isNotEmpty)
        .toList(growable: false);
  }

  /// 单张课程卡 -> Course。字段取不到时给占位文案，不返回 null，
  /// 只有课号彻底读不出来（说明不是课程卡）才丢弃。
  static Course? _parseCourseCard(
    Element card, {
    required int locationIndex,
    required bool isCurrentSemester,
  }) {
    final text = card.text.trim();
    final courseId = _courseIdOf(card, text);
    if (courseId.isEmpty) {
      return null;
    }
    return Course(
      courseId: courseId,
      name: _cardName(card, text, courseId),
      teacher: _cardTeacher(card),
      locationIndex: locationIndex,
      time: _cardTime(card),
      place: _cardPlace(card),
      isCurrentSemester: isCurrentSemester,
    );
  }

  /// 课号。旧项目是「卡片文本第一个空白分隔的 token」，但教务有两种排版：
  /// 一种课号单独一行、一种课号和课程名挤在同一行。硬取第一个 token 会在
  /// 后一种排版下把课程名当成课号。
  ///
  /// 这里改成：先找 `data-course-id`（教务偶尔会挂在卡片容器上），
  /// 再在所有 token 里挑第一个「像课号」的（纯 ASCII、不含中文），
  /// 都挑不出来才退回第一个 token。
  static String _courseIdOf(Element card, String text) {
    final explicit = _explicitCourseId(card);
    if (explicit != null) {
      return explicit;
    }
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    for (final token in tokens) {
      if (_looksLikeCourseId(token)) {
        return token;
      }
    }
    // 课号后面可能直接挂着节次：`M401099B[02]`。这种 token 不「像」课号，
    // 上面那圈找不到，只能取第一个再把尾部的 [02] 摘掉。
    return _trimSectionMarker(tokens.firstOrNull ?? '');
  }

  /// `querySelector` 只看后代，属性挂在卡片容器自身时要先看自己。
  static String? _explicitCourseId(Element card) {
    for (final element in [
      card,
      ...card.querySelectorAll('[data-course-id]'),
    ]) {
      final value = element.attributes['data-course-id']?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// 摘掉课号尾部的节次标记：`M401099B[02]` -> `M401099B`。
  static String _trimSectionMarker(String token) => token
      .replaceFirst(RegExp(r'[\[(（]\s*[0-9A-Za-z]+\s*[\])）]\s*$'), '')
      .trim();

  /// 课号只由字母/数字/点/下划线/短横组成，且不含中文。
  static bool _looksLikeCourseId(String token) {
    if (token.length < 2 || token.length > 32) return false;
    return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(token);
  }

  /// 课程名在 `span` 里。教务的 `text-muted` 是弱化样式，课号和地点都用它，
  /// 所以课程名取第一个「非弱化」的 `span`；万不得已才退回弱化那个。
  ///
  /// 本学期那张表把课号和课程名塞进**同一个** `span`：
  /// `P401048B [02]\n嵌入式系统`。课号有独立字段，名字里再留一份，
  /// 课表格子就被撑成三行（第一行课号、第二行课程名）。
  static String _cardName(Element card, String fallback, String courseId) {
    final spans = card
        .querySelectorAll('span')
        .map((span) => span.text.trim())
        .where((text) => text.isNotEmpty && text != courseId)
        .toList(growable: false);
    final strong = spans.firstWhere(
      (text) => !_isMuted(card, text),
      orElse: () => '',
    );
    return _orUnknown(
      _cleanName(
        strong.isNotEmpty ? strong : spans.firstOrNull ?? fallback,
        courseId,
      ),
    );
  }

  /// 把课程名里混进来的课号 / 节次标记摘掉。
  ///
  /// 两种排版都要管：`P401048B [02]\n嵌入式系统`（换行）和
  /// `M401099B[02] 人工智能的网络应用`（同一行）。只摘**开头**的，
  /// 结尾的 `[本]` 之类标记留着 —— 那是「本学期」的来源标记，有用。
  static String _cleanName(String raw, String courseId) {
    var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    // 只有课号「像课号」时才摘前缀：读不出课号的卡片（选课课表那种）拿到的
    // courseId 其实就是课程名本身，摘了就只剩「[本]」。
    if (_looksLikeCourseId(courseId) && text.startsWith(courseId)) {
      text = text.substring(courseId.length).trim();
    }
    final marker = RegExp(r'^[\[(（]\s*[0-9A-Za-z]+\s*[\])）]\s*');
    if (marker.hasMatch(text)) {
      text = text.replaceFirst(marker, '').trim();
    }
    return text.isEmpty ? raw.replaceAll(RegExp(r'\s+'), ' ').trim() : text;
  }

  /// 文案是否来自弱化元素。课程名不该取自这里，除非整张卡只有弱化文案。
  static bool _isMuted(Element card, String text) => card
      .querySelectorAll('span.text-muted')
      .any((span) => span.text.trim() == text);

  /// 教师名在 `div[style^=max-width] i` 里；旧项目用 `style` 前缀匹配而不是类名，
  /// 教务改版时这条选择器最稳。
  static String _cardTeacher(Element card) {
    final teacher = card.querySelector('div[style^=max-width] i')?.text.trim();
    return (teacher == null || teacher.isEmpty) ? '未知教师' : teacher;
  }

  /// 时间字段跟教师共用那个 `max-width` 容器，教师是里面的 `i`。
  ///
  /// 旧项目直接取容器的 `text`，把教师名也吸了进来（得到 `第1-16周张三`）。
  /// 这里只取容器的直接文本节点，教师由 [_cardTeacher] 单独读。
  static String _cardTime(Element card) {
    final box = card.querySelector('div[style^=max-width]');
    if (box == null) return '未知';
    final time = _squeeze(
      box.nodes.whereType<Text>().map((node) => node.data).join(),
    );
    return time.isEmpty ? '未知' : time;
  }

  /// 地点在 `span.text-muted` 里。
  ///
  /// 同一张卡里可能有多个弱化元素：课号有时候也是弱化的。
  /// 取第一个「不像课号」的；全都像课号时才退回第一个（等于旧项目行为）。
  static String _cardPlace(Element card) {
    final muted = card
        .querySelectorAll('span.text-muted')
        .map((span) => _squeeze(span.text))
        .where((text) => text.isNotEmpty)
        .toList();
    if (muted.isEmpty) {
      return '未知地点';
    }
    for (final text in muted) {
      if (!_looksLikeCourseId(text)) {
        return text;
      }
    }
    return muted.first;
  }

  static String _squeeze(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\s'), '').trim();

  static String _orUnknown(String value) => value.isEmpty ? '未知课程' : value;

  // ---- 课程平台 JSON（兜底）----

  /// 课程平台按学期给的课表。结构看旧项目 `CourseJsonType`。
  ///
  /// 注意：这个接口**不返回格子位置**，所以 [SchedulePosition.unknown]；
  /// 这些课程能进「全部课程」列表，但画不到网格上。
  static List<Course> parseCourseListJson(
    String raw, {
    required bool isCurrentSemester,
  }) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic>
        ? (decoded['courseList'] as List<dynamic>? ?? const [])
        : (decoded as List<dynamic>);
    return list
        .map(
          (item) => parseCourseJson(
            (item as Map).cast<String, dynamic>(),
            isCurrentSemester: isCurrentSemester,
          ),
        )
        .where((course) => course.courseId.isNotEmpty)
        .toList();
  }

  static Course parseCourseJson(
    Map<String, dynamic> json, {
    required bool isCurrentSemester,
  }) {
    return Course(
      courseId: _string(json['course_num']) ?? _string(json['courseId']) ?? '',
      name: _string(json['name']) ?? _string(json['courseName']) ?? '',
      teacher:
          _string(json['teacher_name']) ?? _string(json['teacherName']) ?? '',
      locationIndex:
          int.tryParse('${json['locationIndex'] ?? ''}') ??
          SchedulePosition.unknown,
      time: _buildTimeRange(json['begin_date'], json['end_date']),
      place: '',
      isCurrentSemester: isCurrentSemester,
    );
  }

  /// 课程平台只给起止日期，这里原样呈现 `2026-02-23~2026-07-05`。
  ///
  /// 旧实现把它换算成「第x-y周」，但换算基准是"今天"，一个学期开始时
  /// 会算出 `第20-36周` 这种既超学期长度、又和教务口径不一致的周次，
  /// 反而会误导周次过滤。宁可只显示日期：日期里没有周次信息，
  /// [ScheduleWeeks] 解析不出周次，课程按"始终显示"处理（见其文档）。
  static String _buildTimeRange(Object? begin, Object? end) {
    final beginDate = _parseDate(begin);
    final endDate = _parseDate(end);
    if (beginDate == null && endDate == null) return '';
    if (beginDate == null) return endDate!;
    if (endDate == null || beginDate == endDate) return beginDate;
    return '$beginDate~$endDate';
  }

  /// 归一化成 `yyyy-MM-dd`；平台偶尔给 `2026/02/23` 或带时分秒。
  static String? _parseDate(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw.replaceAll('/', '-'));
    if (parsed == null) return null;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }

  // ---- 通用小工具 ----

  /// 学期列表（旧 `SemesterJsonType`）。
  static List<Semester> parseSemesterList(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic>
        ? (decoded['semesterList'] as List<dynamic>? ?? const [])
        : (decoded as List<dynamic>);
    return list.map((item) {
      final json = (item as Map).cast<String, dynamic>();
      return Semester(
        code: _string(json['xqCode']) ?? _string(json['code']) ?? '',
        name: _string(json['xqName']) ?? _string(json['name']) ?? '',
        isCurrent: json['isCurrent'] as bool? ?? false,
      );
    }).toList();
  }

  /// 当前教学周：`{"weekCode": "12"}`，也兼容直接返回数字/字符串。
  static int parseCurrentWeek(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return int.tryParse('${decoded['weekCode'] ?? ''}') ?? 0;
    }
    return int.tryParse(raw.trim()) ?? 0;
  }

  /// 从教室状态页的最终地址里取当前教学周（`?zc=13`）。
  static int parseWeekFromQuery(String? raw) => int.tryParse(raw ?? '') ?? 0;

  /// 课程平台的课程清单（作业、课件都按这里的一门课去查）。
  ///
  /// 结构看旧项目 `CourseJsonType.courseList`。这里只留平台主键和教师工号，
  /// 格子位置一概没有 —— 那是 [parseScheduleHtml] 的事。
  static List<PlatformCourse> parsePlatformCourseList(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic>
        ? (decoded['courseList'] as List<dynamic>? ?? const [])
        : (decoded as List<dynamic>);
    return [
      for (final item in list)
        if (item is Map) _platformCourseOf(item.cast<String, dynamic>()),
    ].where((course) => course.id != 0).toList();
  }

  static PlatformCourse _platformCourseOf(
    Map<String, dynamic> json,
  ) => PlatformCourse(
    id: _int(json['id']) ?? 0,
    courseNum: _string(json['course_num']) ?? _string(json['courseNum']) ?? '',
    name: _string(json['name']) ?? _string(json['course_name']) ?? '',
    teacherName:
        _string(json['teacher_name']) ?? _string(json['teacherName']) ?? '',
    teacherId: _string(json['teacher_id']) ?? _string(json['teacherId']) ?? '',
    fzId: _string(json['fz_id']) ?? _string(json['fzId']) ?? '',
    semesterCode: _string(json['xq_code']) ?? _string(json['xqCode']) ?? '',
  );

  /// 课程平台会话：`{"sessionId": "..."}`。后面每个平台请求都要带 `sessionid` 头。
  static String parseSessionId(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return _string(decoded['sessionId']) ?? '';
    }
    return '';
  }

  /// 学期号要回填给每门课：课件资源树和教学日历都按 `xqCode` 过滤。
  ///
  /// [parsePlatformCourseList] 拿到的 `xq_code` 有时是空的（平台按学期查课时
  /// 不一定回填），所以这里允许由调用方用 [currentSemesterCode] 补上。
  static List<PlatformCourse> withSemester(
    List<PlatformCourse> courses,
    String semesterCode,
  ) {
    if (semesterCode.isEmpty) return courses;
    return [
      for (final course in courses)
        if (course.semesterCode.isEmpty)
          course.copyWith(semesterCode: semesterCode)
        else
          course,
    ];
  }

  /// 当前学期号。响应 `{"result": [{"xqCode": "2025-2026-1", ...}]}`。
  ///
  /// 拿不到就是空串，不猜：学期猜错的话后面所有课程查询都是错的。
  static String parseCurrentSemesterCode(String raw) {
    final decoded = jsonDecode(raw);
    final list = decoded is Map<String, dynamic>
        ? (decoded['result'] as List<dynamic>? ?? const [])
        : const [];
    for (final item in list) {
      if (item is! Map) continue;
      final code = _string(item.cast<String, dynamic>()['xqCode']);
      if (code != null) return code;
    }
    return '';
  }

  static int? _int(Object? value) => int.tryParse('${value ?? ''}'.trim());

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
