import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';
import '../../models/course/platform_course.dart';
import '../../models/homework/homework_model.dart';

/// 作业（智慧教学平台）。
///
/// 平台的作业接口**按课程逐个查**（`cId`），不是一次给全量；
/// 而且必须带 `sessionid` 头，所以每个方法都要收 [headers]。
/// 端点与字段见旧项目 `SmartCurriculumPlatformRepository` / `HomeworkUploader`。
class HomeworkApi {
  const HomeworkApi(this._request);

  final RequestManager _request;

  /// 某门课某一类作业。`subType`：0 作业 / 1 课程设计 / 2 实验报告。
  Future<String> fetchListRaw({
    required int courseId,
    required HomeworkType type,
    required Map<String, String> headers,
  }) => _request.getText(
    ApiConstants.homeworkUrl,
    query: {
      'method': 'getHomeWorkList',
      'cId': '$courseId',
      'subType': '${type.value}',
      'page': 1,
      'pagesize': 100,
    },
    headers: headers,
  );

  /// 作业详情。[teacherId] 是课程对应的教师工号，平台少了它不给正文。
  Future<String> fetchDetailRaw({
    required Homework note,
    required PlatformCourse course,
    required Map<String, String> headers,
  }) => _request.getText(
    ApiConstants.homeworkUrl,
    query: {
      'method': 'queryStudentCourseNote',
      'id': '${note.upId}',
      'courseId': '${course.id}',
      'teacherId': course.teacherId,
    },
    headers: headers,
  );

  /// 教师随作业下发的附件。
  Future<List<int>> downloadAttachment({
    required Homework note,
    required int attachmentId,
    required Map<String, String> headers,
  }) => _request.downloadBytes(
    ApiConstants.platformDataActionUrl,
    query: {
      'method': 'downLoadPic',
      'id': '$attachmentId',
      'noteId': '${note.upId}',
    },
    headers: headers,
  );

  /// 第一步：把文件本体传上去，换回一个 `visitName` 之类的元信息。
  Future<String> uploadFileRaw({
    required Homework note,
    required String filePath,
    required Map<String, String> headers,
  }) => _request.postMultipart(
    ApiConstants.homeworkUploadUrl,
    query: {'noteId': '${note.upId}'},
    fileField: 'file',
    filePath: filePath,
    headers: headers,
  );

  /// 第二步：把第一步的文件列表连同正文提交，交作业才算完成。
  Future<String> submitRaw({
    required Homework note,
    required String fileListJson,
    required String content,
    required Map<String, String> headers,
  }) => _request.postForm(
    ApiConstants.courseWorkInfoUrl,
    {
      'content': content,
      'groupName': '',
      'groupId': '',
      'courseId': '${note.courseId}',
      'contentType': '${note.homeworkType.value}',
      'fz': '0',
      'jxrl_id': '',
      'fileList': fileListJson,
      'upId': '${note.upId}',
      'return_num': '',
      'isTeacher': '0',
      'stuId': '',
      'currentStuId': '',
    },
    query: {'method': 'sendStuHomeWorks'},
    headers: headers,
  );

  /// 老师批改后的分数。这是一个 HTML 页，分数在 `input#oldScore[value]` 里。
  Future<String> fetchScorePageRaw({
    required Homework note,
    required Map<String, String> headers,
  }) => _request.getText(
    ApiConstants.courseWorkInfoUrl,
    query: {
      'method': 'piGaiDiv',
      'upId': '${note.upId}',
      'id': '${note.idSnId}',
      'uLevel': '1',
      'type': '1',
      'username': 'null',
      'userId': '${note.userId}',
    },
    headers: headers,
  );
}
