import '../models/classroom/classroom_model.dart';
import '../remote/api/classroom_api.dart';
import '../remote/parsers/classroom_parser.dart';
import '../remote/parsers/course_parser.dart';

/// 空教室查询。纯网络数据，没有本地表，也不缓存。
///
/// 两个来源是互补的，缺一不可：
/// 1. 教务教室使用查询（主源）：整周 49 格占用 + 容量，决定列表里有哪些教室；
/// 2. 第三方容量服务（副源）：只有「此刻多少人」，挂在每间教室上。
///
/// 这里是两次独立请求，界面上也分开处理 —— 副源挂了，课表照常出，
/// 只是每间教室少一条人数信息。
class ClassroomRepository {
  ClassroomRepository({required ClassroomApi api}) : _api = api;

  final ClassroomApi _api;

  /// 某栋楼此刻的教室人数（第三方服务）。这栋楼不在服务覆盖范围里就别调。
  Future<BuildingInfo> fetchBuilding({required String buildingName}) async {
    final raw = await _api.fetchBuildingOccupancyRaw(
      buildingName: buildingName,
    );
    return ClassroomParser.parseBuildingInfo(raw, buildingName: buildingName);
  }

  /// 入口页 + 当前教学周。入口的最终地址要留着：切周时复用它，
  /// 就只多发一条 room_view，而不是每翻一页先把入口重走一遍。
  Future<({Uri entryUri, int week})> openEntry() async {
    final entry = await _api.fetchStatusEntry();
    final week = CourseParser.parseWeekFromQuery(entry.queryParameter('zc'));
    if (week <= 0) {
      throw StateError('没能拿到当前教学周（教务没给 zc 参数）');
    }
    return (entryUri: entry.finalUri, week: week);
  }

  /// 某栋楼某一个教学周的整周占用（教务教室使用查询）。
  Future<ClassroomWeekStatus> fetchWeekStatus({
    required Uri entryUri,
    required int week,
    required String buildingId,
  }) async {
    final page = await _api.fetchStatusPage(
      entryUri: entryUri,
      week: week,
      buildingId: buildingId,
    );
    return ClassroomParser.parseWeekStatus(page, week: week);
  }
}
