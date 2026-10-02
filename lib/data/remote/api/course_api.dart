import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';

/// 课表 / 学期 / 周次。
class CourseApi {
  const CourseApi(this._request);

  final RequestManager _request;

  /// 教务课表页面（HTML 表格）。课表数据的**主来源**：
  /// 只有这个页面同时给出了格子位置、周次、教师和地点。
  Future<String> fetchSchedulePage({required bool isCurrentSemester}) =>
      _request.getText(
        isCurrentSemester
            ? ApiConstants.aaScheduleCurrentPage
            : ApiConstants.aaScheduleHistoryPage,
      );

  /// 教室状态入口页。当前教学周藏在 302 之后的 `zc` 参数里，所以这里要最终地址。
  Future<FetchedText> fetchClassroomStatusEntry() =>
      _request.getTextWithFinalUri(ApiConstants.aaClassroomStatusEntryUrl);

  /// 兜底：课程平台的当前教学周。
  Future<String> fetchCurrentWeekRaw() =>
      _request.getText(ApiConstants.currentWeekUrl);

  /// 兜底：课程平台的学期列表。
  Future<String> fetchSemesterTypes() =>
      _request.getText(ApiConstants.semesterTypeUrl);

  /// 当前学期号（`xqCode`）。响应是 `{"result": [{"xqCode": "...", ...}]}`。
  ///
  /// 作业和课件都要先有这个学期号才能换课程清单，
  /// 所以它和 [fetchSemesterTypes] 是两回事：那个列全部学期，这个只要当前。
  Future<String> fetchCurrentSemesterRaw({Map<String, String>? headers}) =>
      _request.getText(ApiConstants.currentSemesterUrl, headers: headers);

  /// 兜底：课程平台按学期给课表，但只返回课程名/教师/周次，**没有格子位置**。
  ///
  /// 同一份数据也是作业 / 课件的入口，所以叫 `courseList` 而不是 `schedule`。
  Future<String> fetchCourseListRaw({
    required String semesterCode,
    Map<String, String>? headers,
  }) => _request.getText(
    ApiConstants.courseTypeUrl,
    query: {
      'method': 'getCourseList',
      'page': 1,
      'pagesize': 100,
      'xqCode': semesterCode,
    },
    headers: headers,
  );

  /// 课程平台会话：换 `sessionid`。之后所有平台请求都要带上它。
  Future<String> fetchPlatformSessionRaw({Map<String, String>? headers}) =>
      _request.getText(
        ApiConstants.platformMessageUrl,
        query: {'method': 'getArticleList'},
        headers: headers,
      );

  /// 教务系统功能入口（课表小组件、更新检查用）。
  Future<String> fetchMisCoursePage() =>
      _request.getText(ApiConstants.misModuleUrl);

  /// 课程平台首页（教学日历入口）。
  Future<String> fetchTeachingCalendarPage() =>
      _request.getText(ApiConstants.coursePlatformUrl);
}
