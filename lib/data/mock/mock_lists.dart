import 'dart:math';

import '../models/course/course_model.dart';
import '../models/course/platform_course.dart';
import '../models/courseware/courseware_model.dart';
import '../models/exam/exam_model.dart';
import '../models/grade/grade_model.dart';
import '../models/homework/homework_model.dart';

/// 人工造的 mock 数据。
///
/// 每个模块一对成员：`xxx` 是开关（true = 用 mock，false = 只用真实数据），
/// `xxxs` 是要合并进网络结果的那份 List。仓库在比较前把它们拼到 remote 上，
/// 所以 mock 记录和真实记录走完全一样的入库 / 变更提示链路。
///
/// 每个模块都造了 10 条左右 —— 够撑满列表，排序 / 筛选 / 分组都能真的跑一遍，
/// 不然「只有一条数据」的页面和真实使用是两回事。
abstract final class MockList {
  // ---- 成绩 ----
  static const bool grade = true;
  static const List<Grade> gradePool = [
    Grade(
      courseName: '【Mock】高等数学(上)',
      courseTeacher: '张启明',
      courseScore: '96',
      courseCredits: '5.0',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据',
    ),
    Grade(
      courseName: '【Mock】大学英语(四级)',
      courseTeacher: '李文静',
      courseScore: '88',
      courseCredits: '2.0',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据',
    ),
    Grade(
      courseName: '【Mock】大学物理',
      courseTeacher: '王振华',
      courseScore: '72',
      courseCredits: '4.0',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据',
    ),
    Grade(
      courseName: '【Mock】数据结构',
      courseTeacher: '陈立群',
      courseScore: '85',
      courseCredits: '3.5',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据',
    ),
    Grade(
      courseName: '【Mock】马克思主义基本原理',
      courseTeacher: '刘建华',
      courseScore: '优',
      courseCredits: '3.0',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据：考查课按等第给分',
    ),
    Grade(
      courseName: '【Mock】大学物理实验',
      courseTeacher: '王振华',
      courseScore: '良',
      courseCredits: '1.5',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据',
    ),
    Grade(
      courseName: '【Mock】概率论与数理统计',
      courseTeacher: '赵天成',
      courseScore: '中',
      courseCredits: '3.0',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据',
    ),
    Grade(
      courseName: '【Mock】体育(中长跑)',
      courseTeacher: '孙国强',
      courseScore: '及格',
      courseCredits: '1.0',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据',
    ),
    Grade(
      courseName: '【Mock】大学英语(六级)',
      courseTeacher: '李文静',
      courseScore: '不及格',
      courseCredits: '2.0',
      courseYear: '2025-2026-1',
      tag: '2025-2026-1',
      detail: 'mock 数据：验证不及格标红',
    ),
    Grade(
      courseName: '【Mock】形势与政策',
      courseTeacher: '周文彬',
      courseScore: '缓考',
      courseCredits: '1.0',
      courseYear: '2024-2025-2',
      tag: '2024-2025-2',
      detail: 'mock 数据：上学期，验证按 tag 分学期',
    ),
  ];

  // ---- 课表 ----
  static const bool course = false;
  static const List<Course> coursePool = [
    Course(
      courseId: 'mock-1001',
      name: '【Mock】高等数学(上)',
      teacher: '张启明',
      locationIndex: 1, // 周一第一节
      time: '1-16周(单周)',
      place: '教一201',
    ),
    Course(
      courseId: 'mock-1001',
      name: '【Mock】高等数学(上)',
      teacher: '张启明',
      locationIndex: 3, // 周三第一节
      time: '1-16周(单周)',
      place: '教一201',
    ),
    Course(
      courseId: 'mock-1001',
      name: '【Mock】高等数学(上)',
      teacher: '张启明',
      locationIndex: 17, // 周一第三节
      time: '1-16周(单周)',
      place: '教一201',
    ),
    Course(
      courseId: 'mock-1002',
      name: '【Mock】大学物理',
      teacher: '王振华',
      locationIndex: 19, // 周三第三节
      time: '1-14周',
      place: '理学楼404',
    ),
    Course(
      courseId: 'mock-1002',
      name: '【Mock】大学物理',
      teacher: '王振华',
      locationIndex: 35, // 周三第五节
      time: '1-14周',
      place: '理学楼404',
    ),
    Course(
      courseId: 'mock-1003',
      name: '【Mock】数据结构',
      teacher: '陈立群',
      locationIndex: 10, // 周二第二节
      time: '3-16周',
      place: '教二501',
    ),
    Course(
      courseId: 'mock-1003',
      name: '【Mock】数据结构',
      teacher: '陈立群',
      locationIndex: 28, // 周四第四节
      time: '3-16周',
      place: '教二501',
    ),
    Course(
      courseId: 'mock-1004',
      name: '【Mock】大学英语(四级)',
      teacher: '李文静',
      locationIndex: 37, // 周五第五节
      time: '1-16周',
      place: '外语楼201',
    ),
    Course(
      courseId: 'mock-1005',
      name: '【Mock】马克思主义基本原理',
      teacher: '刘建华',
      locationIndex: 50, // 周二第七节
      time: '1-16周',
      place: '文科楼305',
    ),
    Course(
      courseId: 'mock-1006',
      name: '【Mock】大学物理实验',
      teacher: '王振华',
      locationIndex: 44, // 周四第六节
      time: '9-16周(单周)',
      place: '理学楼实验中心',
    ),
    Course(
      courseId: 'mock-1007',
      name: '【Mock】概率论与数理统计',
      teacher: '赵天成',
      locationIndex: 57, // 周一第八节
      time: '1-16周',
      place: '教三210',
    ),
    Course(
      courseId: 'mock-1008',
      name: '【Mock】体育(中长跑)',
      teacher: '孙国强',
      locationIndex: 53, // 周五第七节
      time: '1-16周',
      place: '东操场',
    ),
    Course(
      courseId: 'mock-1009',
      name: '【Mock】线性代数',
      teacher: '吴敏行',
      locationIndex: 12, // 周四第二节
      time: '2-16周',
      place: '教二305',
    ),
    Course(
      courseId: 'mock-1010',
      name: '【Mock】大学英语(六级)',
      teacher: '李文静',
      locationIndex: 25, // 周一第四节
      time: '2-16周',
      place: '外语楼305',
    ),
  ];

  // ---- 考试 ----
  static const bool exam = true;

  /// 考试倒计时依赖「今天」，所以这里用相对日期而不是写死的年月日。
  static final List<ExamSchedule> examPool = [
    ExamSchedule(
      examType: '期末',
      courseName: '【Mock】高等数学(上)',
      examTimeAndPlace: '${_at(3, 9, 0)}-11:00 教一201',
      examStatus: '正常',
      detail: 'mock 数据',
    ),
    ExamSchedule(
      examType: '期中',
      courseName: '【Mock】大学物理',
      examTimeAndPlace: '${_at(0, 8, 0)}-10:00 理学楼404',
      examStatus: '正常',
      detail: 'mock 数据',
    ),
    ExamSchedule(
      examType: '补考',
      courseName: '【Mock】大学英语(四级)',
      examTimeAndPlace: '待定',
      examStatus: '待定',
      detail: 'mock 数据：故意留空，验证「时间待定」不倒计时',
    ),
    ExamSchedule(
      examType: '期末',
      courseName: '【Mock】大学英语(六级)',
      examTimeAndPlace: '${_at(10, 13, 30)}-15:30 逸夫303',
      examStatus: '正常',
      detail: 'mock 数据',
    ),
    ExamSchedule(
      examType: '期末',
      courseName: '【Mock】数据结构',
      examTimeAndPlace: '${_at(7, 9, 0)}-11:00 教二501',
      examStatus: '正常',
      detail: 'mock 数据',
    ),
    ExamSchedule(
      examType: '期中',
      courseName: '【Mock】线性代数',
      examTimeAndPlace: '${_at(-5, 14, 0)}-16:00 教二305',
      examStatus: '正常',
      detail: 'mock 数据：已过去，验证「已结束」分组',
    ),
    ExamSchedule(
      examType: '期末',
      courseName: '【Mock】马克思主义基本原理',
      examTimeAndPlace: '${_at(1, 15, 0)}-17:00 线上',
      examStatus: '正常',
      detail: 'mock 数据：线上考试，地点不是教室',
    ),
    ExamSchedule(
      examType: '期末',
      courseName: '【Mock】大学物理实验',
      examTimeAndPlace: '${_at(5, 10, 0)}-12:00 理学楼实验中心',
      examStatus: '正常',
      detail: 'mock 数据',
    ),
    ExamSchedule(
      examType: '随堂',
      courseName: '【Mock】概率论与数理统计',
      examTimeAndPlace: '${_at(2, 10, 0)}-11:30 教三210',
      examStatus: '正常',
      detail: 'mock 数据',
    ),
    ExamSchedule(
      examType: '期末',
      courseName: '【Mock】体育(中长跑)',
      examTimeAndPlace: '${_at(14, 8, 30)}-10:00 东操场',
      examStatus: '正常',
      detail: 'mock 数据',
    ),
  ];

  // ---- 作业 ----
  static const bool homework = true;
  static final List<Homework> homeworkPool = [
    Homework(
      upId: 900001,
      courseId: 9001,
      courseName: '【Mock】高等数学(上)',
      title: '第三章习题',
      content: 'mock 作业正文',
      createDate: _at(-7, 10, 0),
      openDate: _at(-7, 10, 0),
      endTime: _at(2, 23, 59),
      status: 1,
      submitCount: 0,
      allCount: 30,
      subStatus: '未提交',
    ),
    Homework(
      upId: 900002,
      courseId: 9001,
      courseName: '【Mock】高等数学(上)',
      title: '第一次小测',
      createDate: _at(-14, 10, 0),
      openDate: _at(-14, 10, 0),
      endTime: _at(-3, 23, 59),
      status: 1,
      submitCount: 30,
      allCount: 30,
      subStatus: Homework.submittedStatus,
      score: '88',
      scoreId: 1,
    ),
    Homework(
      upId: 900003,
      courseId: 9002,
      courseName: '【Mock】大学物理',
      title: '实验报告一：自由落体',
      createDate: _at(-2, 9, 0),
      openDate: _at(-2, 9, 0),
      endTime: _at(1, 12, 0),
      status: 1,
      submitCount: 0,
      allCount: 28,
      subStatus: '未提交',
      homeworkType: HomeworkType.experimentReport,
    ),
    Homework(
      upId: 900004,
      courseId: 9001,
      courseName: '【Mock】高等数学(上)',
      title: '第四次作业',
      createDate: _at(-10, 10, 0),
      openDate: _at(-10, 10, 0),
      endTime: _at(-6, 23, 59),
      status: 1,
      submitCount: 30,
      allCount: 30,
      subStatus: Homework.submittedStatus,
      score: '92',
      scoreId: 1,
    ),
    Homework(
      upId: 900005,
      courseId: 9003,
      courseName: '【Mock】数据结构',
      title: '实验二：二叉排序树',
      createDate: _at(-20, 9, 0),
      openDate: _at(-20, 9, 0),
      endTime: _at(-12, 23, 59),
      status: 1,
      submitCount: 40,
      allCount: 40,
      subStatus: Homework.submittedStatus,
      score: '95',
      scoreId: 1,
      homeworkType: HomeworkType.courseDesign,
    ),
    Homework(
      upId: 900006,
      courseId: 9003,
      courseName: '【Mock】数据结构',
      title: '第五次作业',
      createDate: _at(-5, 10, 0),
      openDate: _at(-5, 10, 0),
      endTime: _at(-1, 23, 59),
      status: 1,
      submitCount: 0,
      allCount: 40,
      subStatus: '未提交',
    ),
    Homework(
      upId: 900007,
      courseId: 9002,
      courseName: '【Mock】大学物理',
      title: '课堂练习三：动量守恒',
      createDate: _at(-9, 9, 0),
      openDate: _at(-9, 9, 0),
      endTime: _at(-4, 23, 59),
      status: 1,
      submitCount: 28,
      allCount: 28,
      subStatus: Homework.submittedStatus,
      score: '76',
      scoreId: 1,
    ),
    Homework(
      upId: 900008,
      courseId: 9001,
      courseName: '【Mock】高等数学(上)',
      title: '期中复习提纲',
      createDate: _at(-1, 10, 0),
      openDate: _at(-1, 10, 0),
      endTime: _at(6, 23, 59),
      status: 1,
      submitCount: 0,
      allCount: 30,
      subStatus: '未提交',
    ),
    Homework(
      upId: 900009,
      courseId: 9003,
      courseName: '【Mock】数据结构',
      title: '实验报告三：最短路径',
      createDate: _at(-1, 9, 0),
      openDate: _at(-1, 9, 0),
      endTime: _at(4, 23, 59),
      status: 1,
      submitCount: 0,
      allCount: 40,
      subStatus: '未提交',
      homeworkType: HomeworkType.experimentReport,
    ),
    Homework(
      upId: 900010,
      courseId: 9002,
      courseName: '【Mock】大学物理',
      title: '小组作业：受力分析',
      createDate: _at(0, 9, 0),
      openDate: _at(0, 9, 0),
      endTime: _at(9, 18, 0),
      status: 1,
      submitCount: 0,
      allCount: 28,
      subStatus: '未提交',
      homeworkType: HomeworkType.courseDesign,
    ),
  ];


  // ---- 课件 ----

  /// 课件走的是整棵资源树：不落库、只缓存成一份 JSON，所以 mock 直接造一棵树，
  /// 在 `refreshTree` 里挂在真实根节点后面。
  static const bool courseware = true;

  static final PlatformCourse _cwMath = PlatformCourse(
    id: 9001,
    courseNum: 'MATH1001',
    name: '【Mock】高等数学(上)',
    teacherName: '张启明',
    teacherId: 'T1001',
    fzId: 'FZ1001',
    semesterCode: '2025-2026-1',
  );

  static final PlatformCourse _cwPhysics = PlatformCourse(
    id: 9002,
    courseNum: 'PHYS1002',
    name: '【Mock】大学物理',
    teacherName: '王振华',
    teacherId: 'T1002',
    fzId: 'FZ1002',
    semesterCode: '2025-2026-1',
  );

  static final PlatformCourse _cwData = PlatformCourse(
    id: 9003,
    courseNum: 'CS2003',
    name: '【Mock】数据结构',
    teacherName: '陈立群',
    teacherId: 'T1003',
    fzId: 'FZ1003',
    semesterCode: '2025-2026-1',
  );

  static final PlatformCourse _cwEnglish = PlatformCourse(
    id: 9004,
    courseNum: 'EN1004',
    name: '【Mock】大学英语(四级)',
    teacherName: '李文静',
    teacherId: 'T1004',
    fzId: 'FZ1004',
    semesterCode: '2025-2026-1',
  );

  static final PlatformCourse _cwMao = PlatformCourse(
    id: 9005,
    courseNum: 'MAR1005',
    name: '【Mock】马克思主义基本原理',
    teacherName: '刘建华',
    teacherId: 'T1005',
    fzId: 'FZ1005',
    semesterCode: '2025-2026-1',
  );

  static final PlatformCourse _cwProb = PlatformCourse(
    id: 9006,
    courseNum: 'MA2006',
    name: '【Mock】概率论与数理统计',
    teacherName: '赵天成',
    teacherId: 'T1006',
    fzId: 'FZ1006',
    semesterCode: '2025-2026-1',
  );

  static final List<CoursewareNode> coursewarePool = [
    _root(_cwMath, [
      _bag('9101', '第一章 极限与连续', _cwMath, [
        _file('91011', '1.1 序列极限.mp4', 'mp4', '48.2 MB', _cwMath, -21),
        _file('91012', '1.2 夹逼准则.pdf', 'pdf', '1.4 MB', _cwMath, -19),
        _file('91013', '第一章习题讲解.mp4', 'mp4', '62.7 MB', _cwMath, -18),
        _file('91014', '第一章作业答案.pdf', 'pdf', '860 KB', _cwMath, -17),
      ]),
      _bag('9102', '第三章 导数及其应用', _cwMath, [
        _file('91021', '3.1 微分与导数.pdf', 'pdf', '3.1 MB', _cwMath, -7),
        _file('91022', '3.2 中值定理.mp4', 'mp4', '55.3 MB', _cwMath, -6),
        _file('91023', '3.3 洛必达法则.pptx', 'pptx', '8.4 MB', _cwMath, -5),
      ]),
      _bag('9103', '往年真题', _cwMath, [
        _file('91031', '2024-2025学年期末真题.pdf', 'pdf', '2.2 MB', _cwMath, -33),
        _file('91032', '2023-2024学年期末真题.pdf', 'pdf', '2.4 MB', _cwMath, -220),
      ]),
      _file('91099', '课程大纲.pdf', 'pdf', '218 KB', _cwMath, -40),
    ]),
    _root(_cwPhysics, [
      _bag('9201', '实验指导书', _cwPhysics, [
        _file('92011', '实验一 自由落体.pdf', 'pdf', '2.6 MB', _cwPhysics, -12),
        _file('92012', '数据记录表.xlsx', 'xlsx', '96 KB', _cwPhysics, -12),
        _file('92013', '实验二 斜面小车.zip', 'zip', '18.7 MB', _cwPhysics, -11),
      ]),
      _bag('9202', '习题课', _cwPhysics, [
        _file('92021', '第一章 质点运动学.pptx', 'pptx', '12.8 MB', _cwPhysics, -25),
        _file('92022', '第一章习题讲解.mp4', 'mp4', '41.0 MB', _cwPhysics, -24),
      ]),
      _file('92099', '课程大纲.pdf', 'pdf', '196 KB', _cwPhysics, -41),
    ]),
    _root(_cwData, [
      _bag('9301', '实验', _cwData, [
        _file('93011', '实验一 线性表.docx', 'docx', '740 KB', _cwData, -16),
        _file('93012', '实验二 二叉排序树.docx', 'docx', '1.1 MB', _cwData, -8),
        _file('93013', '实验三 最短路径.docx', 'docx', '1.3 MB', _cwData, -3),
      ]),
      _bag('9302', '算法设计', _cwData, [
        _file('93021', '第一章 绪论.pptx', 'pptx', '6.3 MB', _cwData, -30),
        _file('93022', '排序算法对比.mp4', 'mp4', '33.9 MB', _cwData, -28),
        _file('93023', '复杂度分析速查.pdf', 'pdf', '410 KB', _cwData, -27),
      ]),
      _file('93099', '课程大纲.pdf', 'pdf', '204 KB', _cwData, -42),
    ]),
    _root(_cwEnglish, [
      _bag('9401', 'Unit 1-4', _cwEnglish, [
        _file('94011', 'Unit1 Presentation.pptx', 'pptx', '9.1 MB', _cwEnglish, -20),
        _file('94012', 'Unit2 Listening.mp3', 'mp3', '7.4 MB', _cwEnglish, -18),
        _file('94013', 'Unit3 Vocabulary.pdf', 'pdf', '640 KB', _cwEnglish, -15),
      ]),
      _file('94099', '四级考试大纲.pdf', 'pdf', '182 KB', _cwEnglish, -45),
    ]),
    _root(_cwMao, [
      _bag('9501', '专题讲解', _cwMao, [
        _file('95001', '第一章 世界的物质性.pptx', 'pptx', '11.2 MB', _cwMao, -22),
        _file('95002', '第二章 实践与认识.pptx', 'pptx', '10.8 MB', _cwMao, -21),
        _file('95003', '重点名词解释汇总.pdf', 'pdf', '520 KB', _cwMao, -9),
      ]),
      _file('95099', '课程大纲.pdf', 'pdf', '176 KB', _cwMao, -44),
    ]),
    _root(_cwProb, [
      _bag('9601', '第一章 随机事件', _cwProb, [
        _file('96011', '第一章 随机事件.pptx', 'pptx', '9.8 MB', _cwProb, -14),
        _file('96012', '古典概型例题.pdf', 'pdf', '1.6 MB', _cwProb, -13),
      ]),
      _bag('9602', '复习资料', _cwProb, [
        _file('96021', '期末复习提纲.pdf', 'pdf', '890 KB', _cwProb, -2),
        _file('96022', '公式速记表.png', 'png', '1.2 MB', _cwProb, -2),
        _file('96023', '习题课回放.mp4', 'mp4', '58.4 MB', _cwProb, -1),
      ]),
    ]),
  ];

  static CoursewareNode _root(PlatformCourse course, List<CoursewareNode> children) =>
      CoursewareNode(
        id: '${course.id}',
        name: course.name,
        kind: CoursewareKind.course,
        course: course,
        children: children,
      );

  static CoursewareNode _bag(
    String id,
    String name,
    PlatformCourse course,
    List<CoursewareNode> children,
  ) =>
      CoursewareNode(
        id: id,
        name: name,
        kind: CoursewareKind.bag,
        course: course,
        children: children,
      );

  /// mock 文件节点。上传时间取相对日期，不会停在 2020 年。
  static CoursewareNode _file(
    String id,
    String name,
    String extension,
    String sizeText,
    PlatformCourse course,
    int dayOffset,
  ) => CoursewareNode(
    id: id,
    name: name,
    kind: CoursewareKind.res,
    rpId: 'rp-$id',
    extension: extension,
    sizeText: sizeText,
    teacherName: course.teacherName,
    updatedAt: _at(dayOffset, 9, 30),
    downloadCount: 100 - int.parse(id.substring(3)) % 60,
    course: course,
  );

  /// 相对今天的 `yyyy-MM-dd HH:mm`，负数表示过去。教务/平台都认这个格式。
  static String _at(int dayOffset, int hour, int minute) {
    final time = DateTime.now().add(Duration(days: dayOffset));
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} '
        '${two(hour)}:${two(minute)}';
  }



  static final Random _random = Random();

  /// 随机改值用的候选池。太小会出现「挑不出不同于当前值的选项」。
  static const List<String> _scores = [
    '96', '92', '88', '85', '79', '72', '68', '优', '良', '中', '及格', '缓考',
  ];
  static const List<String> _teachers = ['张启明', '李文静', '王振华', '陈立群', '赵天成'];
  static const List<String> _places = [
    '教一201', '教二305', '教二501', '教三210', '理学楼404', '外语馆201', '文科楼305',
  ];
  static const List<String> _examStatuses = ['正常', '正常', '正常', '缓考', '取消'];
  static const List<String> _sizes = [
    '218 KB', '740 KB', '1.2 MB', '2.6 MB', '6.3 MB', '12.8 MB', '48.2 MB',
  ];

  // ---- 每次登录重掷 ----

  /// 本次会话的 mock。null = 还没掷。
  static List<Grade>? _grades;
  static List<Course>? _courses;
  static List<ExamSchedule>? _exams;
  static List<Homework>? _homeworks;
  static List<CoursewareNode>? _coursewares;

  /// 每次登录调一次（`SyncCoordinator.syncAll`）：把上一轮掷的结果丢掉，
  /// 下次读取时重新掷 —— 于是每次登录的 mock 都不一样。
  static void beginSession() {
    _grades = null;
    _courses = null;
    _exams = null;
    _homeworks = null;
    _coursewares = null;
  }

  static List<Grade> get grades => _grades ??= _roll(gradePool, _jitterGrade);
  static List<Course> get courses => _courses ??= _roll(coursePool, _jitterCourse);
  static List<ExamSchedule> get exams => _exams ??= _roll(examPool, _jitterExam);
  static List<Homework> get homeworks => _homeworks ??= _roll(homeworkPool, _jitterHomework);
  static List<CoursewareNode> get coursewares =>
      _coursewares ??= _roll(coursewarePool, _jitterCourseware);

  /// 随机取一半到全部，并逐条改值。
  ///
  /// **身份键不动**：成绩是课名、考试是「类型+课名」、课表是「课程+格子+周次」、
  /// 作业是「课程+upId」。身份不变才会在下次同步里被认成「变更 1」；
  /// 身份一变就成了「新增 1 + 删除 1」，变更提示那条路径根本走不到。
  static List<T> _roll<T>(List<T> pool, T Function(T) jitter) {
    // 池子第一条**永远保留**：这样每次登录至少有一条记录和上次是同一个身份键、
    // 只是值变了，首页必定报出「变更 1」。剩下的随机取，随时会少掉几门课 ——
    // 那几条会在下次同步里变成「删除」，正好把删除路径也走一遍。
    final rest = [...pool.skip(1)]..shuffle(_random);
    final keep = _random.nextInt(rest.length + 1);
    return [pool.first, ...rest.take(keep)].map(jitter).toList();
  }

  static Grade _jitterGrade(Grade item) => item.copyWith(
        courseScore: _other(_scores, item.courseScore),
        courseTeacher: _other(_teachers, item.courseTeacher),
      );

  static Course _jitterCourse(Course item) => item.copyWith(
        place: _other(_places, item.place),
        teacher: _other(_teachers, item.teacher),
      );

  static ExamSchedule _jitterExam(ExamSchedule item) => item.copyWith(
        examTimeAndPlace: _reschedule(item.examTimeAndPlace),
        examStatus: _other(_examStatuses, item.examStatus),
      );

  /// 提交状态翻转必改值，所以每次登录至少能看到一条「变更」。
  static Homework _jitterHomework(Homework item) {
    final wasSubmitted = item.subStatus == Homework.submittedStatus;
    return item.copyWith(
      subStatus: wasSubmitted ? '未提交' : Homework.submittedStatus,
      score: wasSubmitted ? '' : _other(_scores, item.score),
      scoreId: wasSubmitted ? 0 : 1,
      endTime: _reschedule(item.endTime),
    );
  }

  /// 课件页真正渲染的是 name / extension / sizeText / teacherName，
  /// `downloadCount` 和 `updatedAt` 根本不显示 —— 只随机那两个等于没随机。
  /// 所以这里随机的是 `sizeText`（必定变，页面上看得见）和「已下载」状态。
  static CoursewareNode _jitterCourseware(CoursewareNode node) => node.copyWith(
        children: _jitterChildren(node.children),
        sizeText: node.sizeText.isEmpty ? null : _other(_sizes, node.sizeText),
        downloadCount: node.canDownload
            ? node.downloadCount + 1 + _random.nextInt(20)
            : null,
        // 三分之一的文件随机标成「已下载」，验证「还剩 N 个」和下载态图标。
        downloadedPath: node.canDownload && _random.nextInt(3) == 0
            ? 'mock://${node.id}'
            : null,
      );

  static List<CoursewareNode> _jitterChildren(List<CoursewareNode> nodes) => [
        for (final node in nodes) _jitterCourseware(node),
      ];

  /// 从 `pool` 里挑一个**不同于** `current` 的值。挑不到就原样返回。
  ///
  /// 故意不给「可能就是原来那个值」留口子：否则某次登录会随机出「零变化」，
  /// 白等一轮同步才发现什么都没变。
  static T _other<T>(List<T> pool, T current) {
    final rest = pool.where((value) => value != current).toList();
    return rest.isEmpty ? current : rest[_random.nextInt(rest.length)];
  }

  /// 把 `yyyy-MM-dd ...` 挪到另一个随机日期。认不出日期（'待定'）就原样返回。
  static String _reschedule(String text) {
    final head = text.length >= 10 ? text.substring(0, 10) : '';
    final current = DateTime.tryParse(head);
    if (current == null) return text;
    // 最多试 8 次；万一都撞上（比如池子里只剩一天），退到一个远日��而不是死循环。
    for (var i = 0; i < 8; i++) {
      final next = DateTime.now().add(Duration(days: _random.nextInt(61) - 30));
      if (_dayOf(next) != _dayOf(current)) {
        return _dayOf(next) + text.substring(10);
      }
    }
    return _dayOf(current.add(const Duration(days: 31))) + text.substring(10);
  }

  static String _dayOf(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)}';
  }
}
