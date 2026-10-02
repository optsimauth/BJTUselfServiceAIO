import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/mock/mock_lists.dart';
import 'package:bjtuselfserviceaio/data/models/courseware/courseware_model.dart';
import 'package:bjtuselfserviceaio/features/exam/exam_timing.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_timing.dart';

/// mock 数据本身的体检：字段格式对得上解析器，身份键不重复。
/// mock 只在仓库里和网络结果合并，这里保证合进去的数据不会把解析器搞崩。
void main() {
  test('成绩身份键不重复（课名去重，否则同步会互相覆盖）', () {
    final identities = MockList.grades.map((item) => item.identity).toList();
    expect(identities.toSet().length, identities.length);
  });

  test('课表身份键不重复（同一门课的多个格子各算一条）', () {
    final identities = MockList.courses.map((item) => item.identity).toList();
    expect(identities.toSet().length, identities.length);
  });

  test('考试身份键不重复（类型+课名）', () {
    final identities = MockList.exams.map((item) => item.identity).toList();
    expect(identities.toSet().length, identities.length);
  });

  test('作业身份键不重复', () {
    final identities = MockList.homeworks.map((item) => item.identity).toList();
    expect(identities.toSet().length, identities.length);
  });

  test('每个模块都有数据，且数量够撑满列表', () {
    expect(MockList.grades.length, greaterThanOrEqualTo(10));
    expect(MockList.courses.length, greaterThanOrEqualTo(10));
    expect(MockList.exams.length, greaterThanOrEqualTo(10));
    expect(MockList.homeworks.length, greaterThanOrEqualTo(10));
    expect(MockList.coursewares, isNotEmpty);
  });

  test('课程都落在课表格子里，否则画不到网格上', () {
    for (final course in MockList.courses) {
      expect(course.isPlaced, isTrue, reason: '${course.name} 的 locationIndex 画不出来');
    }
  });

  test('考试时间要么能倒计时，要么明确是「待定」，绝不瞎猜', () {
    for (final exam in MockList.exams) {
      final timing = ExamTiming.parse(exam.examTimeAndPlace);
      final stated = exam.examTimeAndPlace.trim() == '待定';
      expect(
        timing.hasDate || stated,
        isTrue,
        reason: '${exam.courseName} 的「${exam.examTimeAndPlace}」既解析不出日期，也没写待定',
      );
    }
  });

  test('作业截止时间都能解析成日期', () {
    for (final homework in MockList.homeworks) {
      expect(
        HomeworkTiming.parse(
          endTime: homework.endTime,
          openDate: homework.openDate,
        ).hasDeadline,
        isTrue,
        reason: '${homework.title} 的 endTime 解析不出来',
      );
    }
  });

  test('课件整棵树的身份键不重复', () {
    final identities = MockList.coursewares
        .expand((root) => root.flatten())
        .map((node) => node.identity)
        .toList();
    expect(identities.toSet().length, identities.length);
  });

  test('只有文件能下载，文件夹不能', () {
    for (final node in MockList.coursewares.expand((root) => root.flatten())) {
      expect(node.canDownload, node.kind == CoursewareKind.res, reason: node.name);
    }
  });
}
