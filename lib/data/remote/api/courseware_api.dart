import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';
import '../../models/course/platform_course.dart';

/// 课件（智慧教学平台）。
///
/// 端点与字段见旧项目 `SmartCurriculumPlatformRepository.generateChildrenNodeList`
/// 和 `CoursewareScreen.downloadCourseWareWithOKHttp`。三个关键点：
/// 1. 资源树要**逐层递归**查：根是课程本身（`up_id=0`），文件夹再用它自己的
///    `id` 当 `up_id` 往下查一层，没有一次性拿全树的接口；
/// 2. 平台所有 `.shtml` 都要 `sessionid` 头，所以每个方法都收 [headers]；
/// 3. 文件本体不在平台域名上，要先用 `rpId` 换一个临时地址。
class CoursewareApi {
  const CoursewareApi(this._request);

  final RequestManager _request;

  /// 某一层的资源列表。[upId] 是父节点：根传 `0`，文件夹传它的 `bag.id`。
  ///
  /// 响应的 `bagList` / `resList` 是并列的两个数组：先文件夹后文件。
  Future<String> fetchResourceLayerRaw({
    required PlatformCourse course,
    required String upId,
    required Map<String, String> headers,
  }) => _request.getText(
    ApiConstants.courseResourceUrl,
    query: {
      'method': 'stuQueryUploadResourceForCourseList',
      // courseId 和 cId 传的是同一个值（课程号），平台两个都要。
      'courseId': course.courseNum,
      'cId': course.courseNum,
      'xkhId': course.fzId,
      'xqCode': course.semesterCode,
      'docType': '1',
      'up_id': upId,
      'searchName': '',
    },
    headers: headers,
  );

  /// 换一个临时下载地址。POST 空表单，返回体里 `rpUrl` 才是文件地址。
  Future<String> fetchDownloadUrlRaw({
    required String rpId,
    required Map<String, String> headers,
  }) => _request.postForm(
    ApiConstants.resourceSpaceUrl,
    const {},
    query: {'method': 'rpinfoDownloadUrl', 'rpId': rpId},
    headers: headers,
  );

  /// 探一下最终地址的响应头。真名只写在 `Content-Disposition` 里。
  Future<FetchedHead> fetchDownloadHead({
    required String url,
    required Map<String, String> headers,
  }) => _request.head(url, headers: headers);

  /// 课程平台页（HTML）。`input#teacherId` 是教师工号，
  /// `iframe#pdfIframe` 是教学日历 PDF 的入口。
  ///
  /// 旧项目在这里查了 `teacherId` 却把查询参数丢了（只 GET 了裸地址），
  /// 于是拿到的永远是课程平台首页。这里把参数补回去。
  Future<String> fetchCoursePlatformPageRaw({
    required PlatformCourse course,
    required Map<String, String> headers,
  }) => _request.getText(
    ApiConstants.coursePlatformUrl,
    query: {
      'method': 'toCoursePlatform',
      'courseId': course.courseNum,
      'dataSource': '1',
      'cId': '${course.id}',
      'xkhId': course.fzId,
      'xqCode': course.semesterCode,
    },
    headers: headers,
  );
}
