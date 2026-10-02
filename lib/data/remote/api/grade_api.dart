import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';

/// 成绩：两个来源（ln = 本科生院，lr = 教务）。
class GradeApi {
  const GradeApi(this._request);

  final RequestManager _request;

  /// 旧代码 studentAccountManager.getGrade("ln"/"lr")，打 aa 教务成绩页。
  Future<String> fetchGradeRaw({required String source}) =>
      _request.getText(ApiConstants.aaGradeListUrl(source));

  /// 成绩单 PDF（英文/中文）。
  Future<List<int>> downloadGradeReport({required bool english}) =>
      _request.downloadBytes(ApiConstants.gradePage(english: english));
}
