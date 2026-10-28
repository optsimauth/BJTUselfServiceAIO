import '../models/course/platform_course.dart';
import '../remote/api/course_api.dart';
import '../remote/parsers/course_parser.dart';
import '../remote/platform_session.dart';

/// 本学期我在上的课（课程平台口径）。
///
/// 作业和课件都要按「课程」逐个去查，所以先要有一份课程清单。
/// 一个学期里基本不变，因此缓存到内存；登录态换了调 [invalidate]。
class PlatformCourseRepository {
  PlatformCourseRepository({
    required CourseApi api,
    required CoursePlatformSession session,
  }) : _api = api,
       _session = session;

  final CourseApi _api;
  final CoursePlatformSession _session;

  List<PlatformCourse>? _cache;

  Future<List<PlatformCourse>> currentCourses() async {
    final cached = _cache;
    if (cached != null) return cached;

    final code = await _currentSemesterCode();
    if (code.isEmpty) {
      throw StateError('没能查到当前学期号（queryCurrentXq），课程清单无从查起');
    }
    final raw = await _api.fetchCourseListRaw(
      semesterCode: code,
      headers: await _session.headers(),
    );
    final courses = CourseParser.parsePlatformCourseList(raw);
    if (courses.isEmpty) {
      // 空清单也可能是会话过期：平台把请求当匿名处理时同样回 200 + 空列表。
      // 丢掉会话，让下一次重试重新握手，而不是拿着同一个死 sessionid 反复空转。
      _session.invalidate();
      throw StateError(
        '课程平台在学期 $code 下返回 0 门课：可能这学期确实没选课，也可能接口变了',
      );
    }
    _cache = courses;
    return courses;
  }

  /// 当前学期号。`queryCurrentXq` 只给当前学期，历史课表用不上它。
  Future<String> _currentSemesterCode() async {
    final raw = await _api.fetchCurrentSemesterRaw(
      headers: await _session.headers(),
    );
    return CourseParser.parseCurrentSemesterCode(raw);
  }

  void invalidate() => _cache = null;
}
