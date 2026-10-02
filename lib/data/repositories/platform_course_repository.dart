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
      throw StateError('没能查到当前学期');
    }
    final raw = await _api.fetchCourseListRaw(
      semesterCode: code,
      headers: await _session.headers(),
    );
    final courses = CourseParser.parsePlatformCourseList(raw);
    if (courses.isEmpty) {
      throw StateError('平台没有返回本学期课程');
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
