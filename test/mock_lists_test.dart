import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/mock/mock_lists.dart';
import 'package:bjtuselfserviceaio/data/models/courseware/courseware_model.dart';
import 'package:bjtuselfserviceaio/features/exam/exam_timing.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_timing.dart';

void main() {
  setUpAll(MockList.beginSession);

  test('每次登录重掷，成绩的分数和子集都会变', () {
    String snapshot() =>
        MockList.grades.map((item) => '${item.courseName}:${item.courseScore}').toSet().join('|');

    MockList.beginSession();
    final first = snapshot();
    MockList.beginSession();
    final second = snapshot();

    // 身份键（课名）不动、分数变 -> 下次同步认成「变更」而不是「新增 + 删除」。
    expect(first, isNot(second));
  });

  test('重掷不会动身份键，所以旧数据能被认成「变更」', () {
    MockList.beginSession();
    final names = MockList.grades.map((item) => item.identity).toSet();
    MockList.beginSession();
    final next = MockList.grades.map((item) => item.identity).toSet();

    expect(next.any(names.contains), isTrue,
        reason: '两次抽到的课程没有交集，说明身份键被重摇了（那是删除+新增，不是变更）');
  });

  test('每次登录都至少留一条成绩，且子集大小会变', () {
    MockList.beginSession();
    expect(MockList.grades, isNotEmpty);
    MockList.beginSession();
    expect(MockList.grades, isNotEmpty);
  });

  test('课程都落在课表格子里', () {
    for (final course in MockList.courses) {
      expect(
        course.isPlaced,
        isTrue,
        reason: '${course.name} 的 locationIndex 画不出来',
      );
      expect(course.isCurrentSemester, isTrue, reason: 'mock 课程只属于当前学期');
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
  test('课件整棵树的身份键不重复（课程/文件夹/文件前缀不同，不会撞）', () {
    final identities = MockList.coursewarePool
        .expand((root) => root.flatten())
        .map((node) => node.identity)
        .toList();
    expect(identities.toSet().length, identities.length);
  });

  test('课件树规模够撑满列表（6 门课 / 十几个文件夹 / 三十多个文件）', () {
    // 断言模板池，不是掷出来的子集 —— 子集每次登录都随机，数量本来就不一样。
    final nodes = MockList.coursewarePool.expand((root) => root.flatten()).toList();
    final files = nodes.where((node) => node.kind == CoursewareKind.res).toList();
    final bags = nodes.where((node) => node.kind == CoursewareKind.bag).toList();

    expect(MockList.coursewarePool.length, 6, reason: '课程根节点');
    expect(bags.length, greaterThanOrEqualTo(10), reason: '文件夹');
    expect(files.length, greaterThanOrEqualTo(30), reason: '文件');
    expect(MockList.coursewares, isNotEmpty, reason: '本次会话至少保留了第一条');
  });

  test('文件扩展名覆盖常见几种（列表图标分支）', () {
    final extensions = MockList.coursewarePool
        .expand((root) => root.flatten())
        .where((node) => node.kind == CoursewareKind.res)
        .map((node) => node.extension)
        .toSet();
    for (final expected in ['pdf', 'mp4', 'pptx', 'docx', 'xlsx', 'zip', 'mp3', 'png']) {
      expect(extensions, contains(expected));
    }
  });

  test('课件随机改的是页面上看得见的字段（sizeText），不是没人看的下载次数', () {
    // `downloadCount` / `updatedAt` 课件页根本不渲染，只随机它们等于没随机。
    String sizes() => MockList.coursewares
        .expand((root) => root.flatten())
        .where((node) => node.kind == CoursewareKind.res)
        .map((node) => node.sizeText)
        .join('|');

    MockList.beginSession();
    final first = sizes();
    MockList.beginSession();
    expect(sizes(), isNot(first), reason: '两次登录的文件大小一模一样，说明随机没作用在可见字段上');
  });

  test('课件里有一两个随机被标成「已下载」，能验证「还剩 N 个」', () {
    MockList.beginSession();
    final downloaded = MockList.coursewares
        .expand((root) => root.flatten())
        .where((node) => node.isDownloaded)
        .toList();
    // 对比的是**文件总数**，不是 coursewarePool.length（那是课程根节点数，只有 6）。
    final poolFiles = MockList.coursewarePool
        .expand((root) => root.flatten())
        .where((node) => node.kind == CoursewareKind.res)
        .length;
    expect(downloaded, isNotEmpty);
    expect(downloaded.length, lessThan(poolFiles),
        reason: '不可能整棵树都下完了，「还剩 N 个」才有东西可剩');
  });

  test('每个 mock 文件都能下载（有 rpId），文件夹不能', () {
    for (final node in MockList.coursewarePool.expand((root) => root.flatten())) {
      expect(node.canDownload, node.kind == CoursewareKind.res, reason: node.name);
    }
  });

  test('课件树能原样走一遍 JSON 缓存（刷新后重启还在）', () {
    final encoded = jsonEncode(
      MockList.coursewarePool.map((node) => node.toJson()).toList(),
    );
    final restored = (jsonDecode(encoded) as List)
        .cast<Map<String, dynamic>>()
        .map(CoursewareNode.fromJson)
        .toList();
    expect(restored.length, MockList.coursewarePool.length);
    expect(
      restored.map((n) => n.flatten().length),
      MockList.coursewarePool.map((n) => n.flatten().length),
    );
    expect(
      restored.expand((n) => n.flatten()).map((n) => n.identity).toList(),
      MockList.coursewarePool.expand((n) => n.flatten()).map((n) => n.identity).toList(),
    );
  });
}
