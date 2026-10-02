/// 学校各系统的入口地址。全部集中在这里，不要在 API 层写字符串字面量。
abstract final class ApiConstants {
  // ---- 本科生院 / 教务 ----
  static const String misHost = 'https://mis.bjtu.edu.cn';
  static const String aaHost = 'https://aa.bjtu.edu.cn';
  static const String bksyHost = 'https://bksy.bjtu.edu.cn';

  // ---- 课程平台（智慧教学平台） ----
  static const String coursePlatformHost = 'http://123.121.147.7:88';
  static const String coursePlatformBack =
      '$coursePlatformHost/ve/back/coursePlatform';

  // ---- 第三方教室容量服务 ----
  static const String classroomCapacityHost = 'http://yaya.csoci.com:2333';
  static const String classroomCapacityUrl =
      '$classroomCapacityHost/api/classnum/';

  // ---- 更新检查 ----
  static const String githubLatestReleaseUrl =
      'https://api.github.com/repos/HFDLYS/BJTUselfService/releases/latest';

  // ---- CAS / SSO（验证码就挂在这条链上）----
  static const String ssoUrl = '$misHost/auth/sso/?next=/';
  static const String casHost = 'https://cas.bjtu.edu.cn';
  static const String casLoginPath = '$casHost/auth/login/';

  /// 验证码图片地址，key 来自登录页的 input#id_captcha_0。
  static String captchaImageUrl(String captchaKey) =>
      '$casHost/image/$captchaKey/';

  // ---- 登录相关 ----
  static const String misLoginPage = '$misHost/login';

  /// App 内嵌 WebView 打开的教务首页。
  static const String misHomeUrl = '$misHost/home/';
  static const String misCoursePlatformModuleUrl = '$misHost/module/module/28/';
  static const String misAaModuleUrl = '$misHost/module/module/10/';
  static const String misBksyModuleUrl = '$misHost/module/module/104/';
  static const String misModuleUrl = misCoursePlatformModuleUrl; // 兼容旧引用
  static const String aaLoginPage = '$aaHost/';
  static const String bksySemesterPage =
      '$bksyHost/Admin/SemesterTranPage.aspx?noRemark=1';

  // ---- 校内邮箱（Coremail） ----
  static const String mailboxModuleUrl = '$misHost/module/module/26/';
  static const String mailHost = 'https://mail.bjtu.edu.cn';
  static const String mailJsonUrl = '$mailHost/coremail/s/json';
  static const String mailReadMessageUrl =
      '$mailHost/coremail/XT/jsp/readMessage.jsp';
  static const String mailComposeUrl = '$mailHost/coremail/XT/jsp/compose.jsp';
  static const String mailIndexUrl = '$mailHost/coremail/XT/index.jsp';

  // ---- 成绩 ----
  /// 成绩列表页。`ctype=ln`（本科生院）/ `ctype=lr`（教务）两个来源，
  /// 缺失一份时用另一份兜底。返回 HTML 表格，交给 `GradeParser` 解析。
  static String aaGradeListUrl(String ctype) =>
      '$aaHost/score/scores/stu/view/?page=1&perpage=500&ctype=$ctype';

  static String gradePage({required bool english}) => english
      ? '$aaHost/score/scorecard/stu/student/download_pdf/?type=card_en_sign&has_advance_query='
      : '$aaHost/score/scorecard/stu/student/download_pdf/?type=card_cn_sign&has_advance_query=';

  // ---- 考试 ----
  /// 考试安排表。表头在 `thead`，`tbody` 里每行 6 列：
  /// 序号 / 考试类型 / 课程名称 / 考试时间地点 / 考试状态 / 备注。
  static const String aaExamSchedulePage =
      '$aaHost/examine/examplanstudent/stulist/';

  // ---- 课表 / 周次 ----
  // 教务（本科生院）课表页面：HTML 表格，格子位置/周次/教师/地点全在这里。
  // 这两个页面是课表数据的主来源；课程平台 JSON 只作兜底。
  static const String aaScheduleCurrentPage =
      '$aaHost/course_selection/courseselecttask/schedule/';
  static const String aaScheduleHistoryPage =
      '$aaHost/course_selection/courseselect/stuschedule/';

  /// 教室状态入口：访问后会 302 到带 `zc=<教学周>` 的地址，周次从跳转结果里读。
  static const String aaClassroomStatusEntryUrl =
      '$aaHost/classroom/timeholdresult/room_view/';

  static const String currentWeekUrl =
      '$coursePlatformBack/course.shtml?method=getTimeList';
  static const String semesterTypeUrl =
      '$coursePlatformBack/course.shtml?method=getSemesterTypeList';

  /// 当前学期号（`xqCode`）。作业 / 课件都靠它换课程清单。
  static const String currentSemesterUrl =
      '$coursePlatformHost/ve/back/rp/common/teachCalendar.shtml?method=queryCurrentXq';
  static const String courseTypeUrl = '$coursePlatformBack/course.shtml';
  static const String homeworkUrl = '$coursePlatformBack/homeWork.shtml';
  static const String platformMessageUrl = '$coursePlatformBack/message.shtml';
  static const String courseResourceUrl =
      '$coursePlatformBack/courseResource.shtml';

  /// 课件下载地址换发处（旧 `resourceSpace.shtml?method=rpinfoDownloadUrl`）。
  /// 先 POST 拿一个临时 `rpUrl`，再去文件服务器取本体。
  static const String resourceSpaceUrl =
      '$coursePlatformHost/ve/back/resourceSpace.shtml';
  static const String platformDataActionUrl =
      '$coursePlatformBack/dataSynAction.shtml';
  static const String courseWorkInfoUrl =
      '$coursePlatformHost/ve/back/course/courseWorkInfo.shtml';
  static const String homeworkUploadUrl =
      '$coursePlatformHost/ve/back/rp/common/homeworkUpload.shtml';
  static const String coursePlatformUrl =
      '$coursePlatformBack/coursePlatform.shtml';

  /// 教学日历 PDF 的静态资源前缀（旧代码用路径后 5 段拼接）。
  static const String teachingCalendarHost = 'http://123.121.147.7:1936/kk/rp/';
}
