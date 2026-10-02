import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';

/// 教室：教务教室使用查询（整周占用 + 容量，主源）+ 第三方容量服务（此刻人数，副源）。
class ClassroomApi {
  const ClassroomApi(this._request);

  final RequestManager _request;

  /// 某栋楼此刻的教室人数。第三方服务，不需要登录。
  Future<String> fetchBuildingOccupancyRaw({required String buildingName}) =>
      _request.getText(
        ApiConstants.classroomCapacityUrl,
        query: {'building': buildingName},
        
      );

  /// 教室使用查询入口页。当前教学周藏在 302 之后的 `zc` 参数里，
  /// 所以这里要的是**最终地址**，不是 body。
  Future<FetchedText> fetchStatusEntry() =>
      _request.getTextWithFinalUri(ApiConstants.aaClassroomStatusEntryUrl);

  /// 教室使用查询数据页。
  ///
  /// 入口跳过来的地址只有 `zc` 和学期，一页装不下全校教室，所以要补三个参数：
  /// - [week] 覆盖 `zc` —— 切周就改这一个参数；
  /// - [buildingId] 是教务 `jxlh` 下拉的**数字 ID**。这个参数不给（或给中文楼名）
  ///   只会返回表头，一间教室都查不到；
  /// - `perpage=500` 一栋楼最多几十间，够用。
  Future<String> fetchStatusPage({
    required Uri entryUri,
    required int week,
    required String buildingId,
  }) {
    final query = <String, String>{
      ...entryUri.queryParameters,
      'zc': '$week',
      'jxlh': buildingId,
      'page': '1',
      'perpage': '500',
    };
    return _request.getText(
      entryUri.replace(queryParameters: query).toString(),
    );
  }
}

