import '../../core/platform/platform_service.dart';
import '../../data/models/course/course_model.dart';

/// 桌面/移动端课程表小组件。旧项目是 AppWidget + CourseScheduleWidgetReceiver。
class CourseScheduleWidgetService {
  const CourseScheduleWidgetService({required PlatformService platformService})
    : _platformService = platformService;

  final PlatformService _platformService;

  Future<void> refresh({
    required List<Course> courses,
    required int currentWeek,
  }) async {
    await _platformService.refreshHomeWidget({
      'currentWeek': currentWeek,
      'courses': courses
          .map(
            (course) => {
              'name': course.name,
              'teacher': course.teacher,
              'place': course.place,
              'time': course.time,
              'locationIndex': course.locationIndex,
              'isCurrentSemester': course.isCurrentSemester,
            },
          )
          .toList(),
    });
  }

  Future<void> clear() => _platformService.refreshHomeWidget(const {});
}
