import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';

/// 考试安排。
///
/// 页面在 `https://aa.bjtu.edu.cn/examine/examplanstudent/stulist/`，
/// 返回 HTML 表格而不是 JSON，所以这里返回原始 HTML，交给
/// `ExamParser` 解析。
class ExamApi {
  const ExamApi(this._request);

  final RequestManager _request;

  Future<String> fetchExamScheduleRaw() =>
      _request.getText(ApiConstants.aaExamSchedulePage);
}
