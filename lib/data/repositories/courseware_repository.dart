import 'dart:convert';

import '../../core/state/sync_module.dart';
import '../../core/state/sync_result.dart';
import '../../core/storage/preferences.dart';
import '../../services/download/download_service.dart';
import '../mock/mock_lists.dart';
import '../models/course/platform_course.dart';
import '../models/courseware/courseware_model.dart';
import '../remote/api/courseware_api.dart';
import '../remote/parsers/courseware_parser.dart';
import '../remote/platform_session.dart';
import 'platform_course_repository.dart';
import '../../features/courseware/courseware_tree.dart';

/// 一次「下载全部」的结果。
class CoursewareDownloadSummary {
  const CoursewareDownloadSummary({
    required this.succeededIds,
    required this.failed,
  });

  /// 真的下成功的文件（[CoursewareNode.identity]）。
  ///
  /// 必须逐个报，不能只给个数：整包下到一半失败时，界面上要能把成功的那几个
  /// 标成已下、剩下几个留在「还剩 N 个」里。
  final List<String> succeededIds;

  final int failed;

  int get succeeded => succeededIds.length;

  int get total => succeeded + failed;

  bool get isAllOk => failed == 0;
}

/// 课件。
///
/// 资源树是纯缓存数据（旧代码直接存 DataStore 的 JSON），所以不建表。
/// 树要**逐层**拉：根是课程，文件夹再用它自己的 id 当 `up_id` 往下查一层。
class CoursewareRepository {
  CoursewareRepository({
    required CoursewareApi api,
    required PlatformCourseRepository courseRepository,
    required CoursePlatformSession session,
    required AppPreferences preferences,
    required DownloadService downloadService,
  }) : _api = api,
       _courseRepository = courseRepository,
       _session = session,
       _preferences = preferences,
       _downloadService = downloadService;

  final CoursewareApi _api;
  final PlatformCourseRepository _courseRepository;
  final CoursePlatformSession _session;
  final AppPreferences _preferences;
  final DownloadService _downloadService;

  /// 最多往下递归几层。平台实际用不到 3 层，设个上限是防止
  /// 某个文件夹把自己当子节点时把栈跑满。
  static const int maxDepth = 6;

  /// 上次同步下来的整棵树（可能是空的）。同步之前先拿它渲染。
  List<CoursewareNode> loadCachedTree() {
    final raw = _preferences.coursewareJson;
    if (raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => CoursewareNode.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      // 缓存结构变了就直接当没有，让用户重新同步。
      return const [];
    }
  }

  /// 逐门课递归拉资源树，覆盖缓存。任一门失败就跳过那一门。
  Future<List<CoursewareNode>> refreshTree() async {
    List<PlatformCourse> courses;
    try {
      courses = await _courseRepository.currentCourses();
    } catch (_) {
      courses = const [];
    }
    if (courses.isEmpty && !MockList.courseware) {
      throw StateError('没拿到本学期课程');
    }

    final headers = await _session.headers();
    final roots = <CoursewareNode>[];
    for (final course in courses) {
      // 缺课程号 / 选课助手号 / 学期号的课查不出资源，平台会返回空列表。
      if (!course.canFetchCourseware) continue;
      final children = await _tryLayer(
        course,
        upId: '0',
        headers: headers,
        depth: 0,
      );
      roots.add(
        CoursewareNode(
          id: '${course.id}',
          name: course.name,
          kind: CoursewareKind.course,
          course: course,
          children: children,
        ),
      );
    }
    if (MockList.courseware) {
      roots.addAll(MockList.coursewares);
    }
    if (roots.isEmpty) {
      throw StateError('平台上没查到任何课件');
    }

    await _preferences.setCoursewareJson(
      jsonEncode(roots.map((node) => node.toJson()).toList()),
    );
    return roots;
  }

  /// 拉新树、覆盖缓存，并和上次那份比出新 / 变更 / 删除。
  ///
  /// 课件的「本地库」就是 [loadCachedTree] 那棵 JSON 树：覆盖之前先取出来
  /// 比一遍，比完照常覆盖 —— 首页那行「课件：新增 N，删除 M」来自这里。
  Future<SyncResult> sync() async {
    final previous = CoursewareTree.flatten(loadCachedTree());
    final roots = await refreshTree();
    return SyncResult.fromChanges(
      SyncModule.courseware,
      CoursewareTree.detectChanges(
        remote: CoursewareTree.flatten(roots),
        local: previous,
      ),
      describe: CoursewareTree.describeChange,
    );
  }

  /// 下载一个文件，返回保存后的文件名。
  Future<String> downloadFile(
    CoursewareNode file, {
    List<String> folders = const [],
  }) async {
    if (!file.canDownload) {
      throw StateError('这个课件没有下载地址');
    }
    final headers = await _session.headers();
    final raw = await _api.fetchDownloadUrlRaw(
      rpId: file.rpId,
      headers: headers,
    );
    final url = CoursewareParser.parseDownloadUrl(raw);
    final name = await _fileName(url, headers, fallback: file.name);
    return _download(
      url: url,
      fileName: name,
      taskId: 'courseware.${file.identity}',
      folders: folders,
    );
  }

  /// 递归下载一棵子树里所有还没下的文件。返回成功 / 失败的个数。
  Future<CoursewareDownloadSummary> downloadTree(CoursewareNode node) async {
    final items = CoursewareTree.downloadItemsOf(node, maxDepth: maxDepth);
    if (items.isEmpty) {
      throw StateError('这里没有可下载的课件');
    }
    // 并发下发，并发上限由 DownloadService 的队列统一管（maxConcurrent）。
    //
    // 原来是一个一个 await：12 个文件要等 12 轮往返，进度条也永远只有一行在动。
    // 现在一次把任务全丢进队列，界面上能同时看到多行进度，下完也快得多。
    final results = await Future.wait(
      items.map((item) async {
        try {
          await downloadFile(item.file, folders: item.folders);
          return item.file.identity;
        } catch (_) {
          // 一个文件下不动不影响整包：继续下一个，最后一起报数。
          return null;
        }
      }),
    );
    return CoursewareDownloadSummary(
      succeededIds: results.whereType<String>().toList(),
      failed: results.where((id) => id == null).length,
    );
  }

  Future<String> downloadTeachingCalendar(CoursewareNode courseNode) async {
    final course = courseNode.course;
    if (course == null) {
      throw StateError('这门课没有平台信息');
    }
    final headers = await _session.headers();
    final html = await _api.fetchCoursePlatformPageRaw(
      course: course,
      headers: headers,
    );
    // 先确认工号拿到了 —— 拿不到说明这门课的页面还没生成，后面都是白跑。
    final teacherId = CoursewareParser.parseTeacherId(html);
    if (teacherId.isEmpty) {
      throw StateError('平台上没找到这门课的教学日历');
    }
    final url = CoursewareParser.parseTeachingCalendarUrl(html);
    if (url.isEmpty) {
      throw StateError('平台上没找到这门课的教学日历');
    }
    final name = '${course.name.isEmpty ? '课程' : course.name}_教学日历.pdf';
    return _download(
      url: url,
      fileName: name,
      taskId: 'courseware.calendar.${course.id}',
    );
  }

  /// 拉一层。某一层失败就当它是空的：少一个文件夹不该让整门课的课件消失。
  Future<List<CoursewareNode>> _tryLayer(
    PlatformCourse course, {
    required String upId,
    required Map<String, String> headers,
    required int depth,
  }) async {
    if (depth >= maxDepth) return const [];
    try {
      final raw = await _api.fetchResourceLayerRaw(
        course: course,
        upId: upId,
        headers: headers,
      );
      final layer = CoursewareParser.parseResourceLayer(raw, course: course);
      return [
        for (final node in layer)
          if (node.kind == CoursewareKind.bag)
            node.copyWith(
              children: await _tryLayer(
                course,
                upId: node.id,
                headers: headers,
                depth: depth + 1,
              ),
            )
          else
            node,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// 真名优先从 `Content-Disposition` 取；探不到头就退回平台自己给的名字。
  ///
  /// 平台的 `rpName` 通常就是文件名，但它常常带中文和空格，而 URL 上的路径
  /// 段是编码过的，所以拿不到响应头时用平台名字反而更靠谱。
  Future<String> _fileName(
    String url,
    Map<String, String> headers, {
    required String fallback,
  }) async {
    try {
      final head = await _api.fetchDownloadHead(url: url, headers: headers);
      final fromHeader = CoursewareParser.parseFileName(
        head.header('content-disposition'),
      );
      if (fromHeader.isNotEmpty) return fromHeader;
    } catch (_) {
      // 有些文件服务器不认 HEAD，探不到就按平台名字存。
    }
    return fallback;
  }

  /// 落盘位置由 DownloadService 统一决定（<根目录>/bjtuselfserviceaio/...），
  /// 这里只负责把「该放哪门课的哪个文件夹」这段相对路径传下去。
  Future<String> _download({
    required String url,
    required String fileName,
    required String taskId,
    List<String> folders = const [],
  }) {
    return _downloadService.download(
      url: url,
      fileName: fileName,
      name: taskId,
      folders: folders.map(CoursewareTree.safeSegment).toList(),
    );
  }
}
