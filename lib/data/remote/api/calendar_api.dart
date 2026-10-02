import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';

/// 校历 + 教学日历。
class CalendarApi {
  const CalendarApi(this._request);

  final RequestManager _request;

  /// 本科生院校历页面，真实 PDF 地址藏在 script 里。
  Future<String> fetchSchoolCalendarPage() =>
      _request.getText(ApiConstants.bksySemesterPage);

  /// 校历周日期数据（公开页，同一个 bksy 页面里的 hidJson 隐藏字段）。
  ///
  /// 这是**公开页**，不挂 aa 会话：它决定「第几周对应哪几天」，假期周就在这里。
  Future<String> fetchAcademicWeeksPage() =>
      _request.getText(ApiConstants.bksySemesterPage);

  Future<String> fetchTeachingCalendarPage({required String courseId}) =>
      _request.getText(
        ApiConstants.coursePlatformUrl,
        query: {'courseId': courseId, 'method': 'teachingCalendar'},
      );
}
