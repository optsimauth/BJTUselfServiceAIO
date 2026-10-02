import 'package:flutter/material.dart';

import '../../data/models/course/course_model.dart';
import '../../data/models/exam/exam_model.dart';
import '../../data/models/homework/homework_model.dart';
import '../../shared/theme/spacing.dart';
import '../course/lesson_period.dart';
import '../exam/exam_timing.dart';
import '../homework/homework_timing.dart';
import 'home_calendar.dart';

/// 首页日历事项的详情弹层。点日程条目时调起。
Future<void> showHomeEventDialog(
  BuildContext context, {
  required HomeCalendarEvent event,
  DateTime? now,
}) => showDialog<void>(
  context: context,
  builder: (context) =>
      _HomeEventDialog(event: event, now: now ?? DateTime.now()),
);

class _HomeEventDialog extends StatelessWidget {
  const _HomeEventDialog({required this.event, required this.now});

  final HomeCalendarEvent event;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final fields = _fieldsOf(event, now);
    final title = event.title.isEmpty ? '未命名' : event.title;
    return AlertDialog(
      title: Text('${event.typeLabel} · $title'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 440),
        child: fields.isEmpty
            ? const Text('暂无更多信息')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AlertDialog 会问 intrinsic 宽度，ListView 给不出来
                    //（RenderShrinkWrappingViewport 明确不支持）。
                    // 字段最多十来行，直接用 Column 顺序铺开。
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      _FieldRow(label: fields[i].$1, value: fields[i].$2),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 一行 `标签  值`。整行宽度都给值 —— 时间和地点被挤成一个字一行竖着排
/// 是这类弹层最常见的翻车方式。
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// 按类型取要展示的字段。
///
/// 解析不出来的字段直接不出现（不放「未填写」占位）—— 教务的「待定」
/// 展开成一片灰字只会让人以为数据坏了。
List<(String, String)> _fieldsOf(HomeCalendarEvent event, DateTime now) {
  final rows = switch (event.type) {
    HomeCalendarEventType.course => _courseFields(event.course),
    HomeCalendarEventType.homeworkStart ||
    HomeCalendarEventType.homeworkEnd => _homeworkFields(event.homework, now),
    HomeCalendarEventType.exam => _examFields(event.exam, now),
  };
  return [
    for (final row in rows)
      if (row.$2.isNotEmpty) row,
  ];
}

List<(String, String)> _courseFields(Course? course) {
  if (course == null) return const [];
  final period = SchedulePeriods.bySection(course.section);
  final time = period != null && period.start.isNotEmpty
      ? period.timeRange
      : '';
  final section = SchedulePeriods.labelOf(course.section);
  return [
    ('教师', course.teacher.trim()),
    ('地点', course.place.trim()),
    ('节次', time.isEmpty ? section : '$section · $time'),
    ('周次', course.time.trim()),
  ];
}

List<(String, String)> _homeworkFields(Homework? homework, DateTime now) {
  if (homework == null) return const [];
  final timing = HomeworkTiming.parse(
    endTime: homework.endTime,
    openDate: homework.openDate,
  );
  final countdown = timing.countdownLabel(now);
  final submitCount = homework.allCount > 0
      ? '${homework.submitCount}/${homework.allCount}'
      : '${homework.submitCount}';
  return [
    ('课程', homework.courseName.trim()),
    ('标题', homework.title.trim()),
    ('类型', homework.homeworkType.label),
    ('开放时间', homework.openDate.trim()),
    ('截止时间', _withCountdown(homework.endTime, countdown)),
    ('提交状态', _submitStatus(homework)),
    ('提交次数', submitCount),
    ('成绩', homework.score.trim()),
  ];
}

List<(String, String)> _examFields(ExamSchedule? exam, DateTime now) {
  if (exam == null) return const [];
  final timing = ExamTiming.parse(exam.examTimeAndPlace);
  return [
    ('类型', exam.examType.trim()),
    ('课程', exam.courseName.trim()),
    ('状态', exam.examStatus.trim()),
    ('日期', _withCountdown(timing.dateText, timing.countdownLabel(now))),
    ('时段', timing.timeText.trim()),
    ('地点', timing.place.trim()),
    ('备注', timing.note.trim()),
    // 自由文本拆出来的四段之外还有原文，拆不出来的部分靠它兜底。
    ('原文', exam.examTimeAndPlace.trim()),
  ];
}

/// 「2026-03-05 23:59（还有 3 天）」。
///
/// 倒计时不是「已结束」/「时间待定」时不重复加括号 —— 那两种本身就是结论。
String _withCountdown(String raw, String countdown) {
  final text = raw.trim();
  if (countdown.isEmpty || countdown == '已结束' || countdown == '时间待定') {
    return text;
  }
  return text.isEmpty ? countdown : '$text（$countdown）';
}

/// `subStatus` 空就是没交，别让它显示成一个空行。
String _submitStatus(Homework homework) =>
    homework.subStatus.trim().isEmpty ? '未提交' : homework.subStatus.trim();
