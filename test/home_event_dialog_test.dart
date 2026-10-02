import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
import 'package:bjtuselfserviceaio/data/models/exam/exam_model.dart';
import 'package:bjtuselfserviceaio/data/models/homework/homework_model.dart';
import 'package:bjtuselfserviceaio/features/home/home_calendar.dart';
import 'package:bjtuselfserviceaio/features/home/home_event_dialog.dart';

/// 固定「现在」，倒计时文案才是确定的。
final DateTime _now = DateTime(2026, 3, 1);

Future<void> _tapAndOpen(WidgetTester tester, HomeCalendarEvent event) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showHomeEventDialog(context, event: event, now: _now),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('课程弹层给出教师、地点、节次作息和周次', (tester) async {
    await _tapAndOpen(
      tester,
      HomeCalendarEvent(
        type: HomeCalendarEventType.course,
        date: DateTime(2026, 3, 2),
        course: const Course(
          courseId: 'C1',
          name: '高等数学',
          teacher: '王老师',
          place: '教三201',
          time: '第1-16周',
          locationIndex: 1,
        ),
      ),
    );

    expect(find.text('课程 · 高等数学'), findsOneWidget);
    expect(find.text('王老师'), findsOneWidget);
    expect(find.text('教三201'), findsOneWidget);
    expect(find.text('第一节 · 08:00-09:50'), findsOneWidget);
    expect(find.text('第1-16周'), findsOneWidget);
  });

  testWidgets('作业截止弹层带倒计时和提交状态', (tester) async {
    await _tapAndOpen(
      tester,
      HomeCalendarEvent(
        type: HomeCalendarEventType.homeworkEnd,
        date: DateTime(2026, 3, 2),
        homework: const Homework(
          upId: 1,
          courseName: '高等数学',
          title: '第一次作业',
          endTime: '2026-03-05 23:59',
        ),
      ),
    );

    expect(find.text('作业截止 · 第一次作业'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('2026-03-05 23:59（还有 4 天）'), findsOneWidget);
    expect(find.text('未提交'), findsOneWidget);
  });

  testWidgets('考试弹层把自由文本拆成日期时段地点和备注', (tester) async {
    await _tapAndOpen(
      tester,
      HomeCalendarEvent(
        type: HomeCalendarEventType.exam,
        date: DateTime(2026, 3, 8),
        exam: const ExamSchedule(
          examType: '期末',
          courseName: '大学物理',
          examTimeAndPlace: '2026-03-08(第18周) 08:00-10:00 教四403',
        ),
      ),
    );

    expect(find.text('考试 · 大学物理'), findsOneWidget);
    expect(find.text('期末'), findsOneWidget);
    expect(find.text('2026-03-08（1 周后）'), findsOneWidget);
    expect(find.text('08:00-10:00'), findsOneWidget);
    expect(find.text('教四403'), findsOneWidget);
    expect(find.text('第18周'), findsOneWidget);
  });

  testWidgets('关掉按钮能关掉弹层', (tester) async {
    await _tapAndOpen(
      tester,
      HomeCalendarEvent(
        type: HomeCalendarEventType.exam,
        date: DateTime(2026, 3, 8),
        exam: const ExamSchedule(
          examType: '期末',
          courseName: '大学物理',
          examTimeAndPlace: '2026-03-08 08:00-10:00 教四403',
        ),
      ),
    );

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
