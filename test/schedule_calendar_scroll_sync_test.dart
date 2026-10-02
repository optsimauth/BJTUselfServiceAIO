// 课表表头（星期）和内容必须横向同步：一个 ScrollController 挂不到两个
// ScrollView 上，实现用的是两个 controller + 双向监听。这里横向拖内容，验证表头跟上。
import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
import 'package:bjtuselfserviceaio/data/models/course/schedule_position.dart';
import 'package:bjtuselfserviceaio/features/course/schedule_board.dart';
import 'package:bjtuselfserviceaio/shared/components/calendar/schedule_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('横向拖动课表内容时，星期表头跟着同步滑动', (tester) async {
    final board = ScheduleBoardBuilder.build([
      for (var weekday = 1; weekday <= SchedulePosition.weekdayCount; weekday++)
        Course(
          courseId: 'C$weekday',
          name: '课$weekday',
          locationIndex: SchedulePosition.locationIndex(
            section: 1,
            weekday: weekday,
          ),
        ),
    ]);

    // 手机宽度：7 列 x 78 = 546 > 390，必然横向溢出。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleCalendar(board: board, now: DateTime(2025, 1, 6)),
        ),
      ),
    );
    await tester.pump();

    double xOf(String label) => tester.getTopLeft(find.text(label)).dx;

    // 1) 拖内容：内容色块和星期表头必须一起左移。
    final headerX = xOf('周一');
    final chipX = xOf('课1');
    await tester.drag(find.byType(ScheduleCalendar), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(chipX - xOf('课1'), closeTo(120, 1.0), reason: '内容没滑');
    expect(headerX - xOf('周一'), closeTo(120, 1.0), reason: '表头没跟上内容');

    // 2) 反向拖表头：表头带内容一起回来。
    await tester.dragFrom(const Offset(200, 20), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(xOf('课1') - chipX, closeTo(-60, 1.0), reason: '内容没跟表头');
  });
}
