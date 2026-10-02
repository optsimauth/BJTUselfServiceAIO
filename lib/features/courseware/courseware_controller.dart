import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/model/async_state.dart';
import '../../data/models/courseware/courseware_model.dart';
import '../../data/repositories/courseware_repository.dart';
import 'courseware_tree.dart';

/// 课件页的状态。旧项目 CoursewareViewModel（40 行）+ CoursewareScreen 的展开状态。
///
/// 职责边界：拉数据交给 Repository，这里只管「现在在看什么」——
/// 哪些节点展开着、搜什么、哪几个文件正在下。
class CoursewareController extends ChangeNotifier {
  CoursewareController({required CoursewareRepository repository})
    : _repository = repository {
    _roots = List<CoursewareNode>.from(_repository.loadCachedTree());
    // 缓存里有树就直接点亮界面：进页面先看到上次的内容，网络回来再悄悄换新。
    if (_roots.isNotEmpty) {
      _state = AsyncState<List<CoursewareNode>>.data(_roots);
    }
  }

  final CoursewareRepository _repository;


  bool _disposed = false;

  List<CoursewareNode> _roots = const [];
  final Set<String> _expanded = <String>{};

  /// 已经下过的文件：identity -> 保存位置。
  final Map<String, String> _downloaded = <String, String>{};

  /// 正在下载的文件。存的是个数而不是任务对象：界面上只需要知道「转圈还是完成」。
  final Set<String> _downloading = <String>{};

  String _query = '';
  String? _lastError;
  AsyncState<List<CoursewareNode>> _state =
      AsyncState<List<CoursewareNode>>.idle();

  AsyncState<List<CoursewareNode>> get state => _state;

  /// 上次出错的原因（下载失败之类），成功一次就清掉。
  String? get lastError => _lastError;

  String get query => _query;

  /// 一共几门课有几份文件。空树时两个 0。
  int get totalFiles => CoursewareTree.resourceCount(_roots);

  int get downloadedFiles => _downloaded.length;

  int get pendingFiles => CoursewareTree.pendingCount(_roots);

  /// 正在下的文件数。
  int get activeDownloads => _downloading.length;

  bool get isEmpty => _roots.isEmpty;

  /// 全部课程节点（每门课一张卡）。展开与否由 [isExpanded] 表达。
  List<CoursewareNode> get roots => List<CoursewareNode>.unmodifiable(_roots);

  /// 搜到的东西。空搜索时是空列表，界面据此切回树。
  List<CoursewareSearchResult> get results =>
      _query.trim().isEmpty ? const [] : CoursewareTree.search(_roots, _query);

  bool get isSearching => _query.trim().isNotEmpty;

  /// 这门课还剩几个文件没下。界面上「下载全部」旁边就写这个数。
  int pendingOf(CoursewareNode courseNode) =>
      CoursewareTree.pendingFilesOf(courseNode).length;

  int totalOf(CoursewareNode courseNode) =>
      CoursewareTree.filesOf(courseNode).length;

  bool isExpanded(CoursewareNode node) => _expanded.contains(node.identity);

  bool isDownloading(CoursewareNode node) =>
      _downloading.contains(node.identity);

  bool isDownloaded(CoursewareNode node) =>
      node.isDownloaded || _downloaded.containsKey(node.identity);

  /// 展开 / 收起。文件夹和课程都算。
  void toggle(CoursewareNode node) {
    if (!_expanded.remove(node.identity)) {
      _expanded.add(node.identity);
    }
    notifyListeners();
  }

  /// 跳到某个文件：把它上面的每一层都展开。
  ///
  /// 只展开目标自己是不够的 —— 目标藏在还没打开的文件夹里时，
  /// 「跳过去」和「没反应」在界面上是一回事。
  void reveal(CoursewareNode node) {
    for (final step in CoursewareTree.chainOf(_roots, node.identity)) {
      _expanded.add(step.identity);
    }
    notifyListeners();
  }

  void collapseAll() {
    if (_expanded.isEmpty) return;
    _expanded.clear();
    notifyListeners();
  }

  void search(String keyword) {
    if (_query == keyword) return;
    _query = keyword;
    notifyListeners();
  }

  void clearSearch() => search('');

  /// 拉一次新树。[showLoading] 为 true 时才把界面切成转圈。
  ///
  /// 默认看「现在有没有内容」：已经有树就别切成 loading —— 那一下白屏 +
  /// 转圈正是「每次进来都要等一趟」的来源，后台换新对用户不可见更好。
  Future<void> refresh({bool? showLoading}) async {
    if (showLoading ?? isEmpty) {
      _state = AsyncState<List<CoursewareNode>>.loading();
      notifyListeners();
    }
    try {
      final roots = await _repository.refreshTree();
      if (_disposed) return;
      _roots = roots;
      _lastError = null;
      // 缓存里没标记的「已下载」在整棵树换掉后就不再可信，清掉。
      _downloaded.removeWhere(
        (identity, _) => !_knownIdentities.contains(identity),
      );
      // 展开状态是**用户的选择**，不跟着新树重置：
      // 只清掉这棵树里已经不存在的那些 identity，其余原样保留，
      // 新出现的课程保持折叠。
      _expanded.removeWhere(
        (identity) => !_knownIdentities.contains(identity),
      );
      _state = AsyncState<List<CoursewareNode>>.data(roots);
    } catch (error) {
      if (_disposed) return;
      _lastError = '$error';
      // 已经有缓存就别把界面打成错误页：断网时让用户继续看旧内容，
      // 错误只记在 _lastError 里（页面上提示一句），比整页变红字强。
      if (_roots.isEmpty) {
        _state = AsyncState<List<CoursewareNode>>.error(error);
      }
    }
    notifyListeners();
  }


  /// 下一个文件。成功就把树上的对应节点标成已下载，状态不用等下次同步。
  Future<String> download(CoursewareNode file) async {
    _downloading.add(file.identity);
    _lastError = null;
    notifyListeners();
    try {
      final path = await _repository.downloadFile(
        file,
        folders: CoursewareTree.foldersOf(_roots, file.identity),
      );
      if (_disposed) return path;
      _downloading.remove(file.identity);
      _downloaded[file.identity] = path;
      _roots = CoursewareTree.markDownloaded(_roots, {file.identity: path});
      return path;
    } catch (error) {
      if (_disposed) rethrow;
      _downloading.remove(file.identity);
      _lastError = '$error';
      notifyListeners();
      rethrow;
    }
  }

  /// 一次「下载全部」的结果。
  ///
  /// 整包下载一次要几十个文件，仓库只逐个报 identity、不逐个报落盘位置，
  /// 所以树上的标记统一写这个占位串 —— [CoursewareNode.isDownloaded]
  /// 只看非空，界面要的是「转圈还是已完成」，不是路径。
  static const _batchSavedMark = '已保存';

  /// 下一个文件夹（或一整门课）下所有还没下的文件。
  ///
  /// 只有真的下成功的那些会标成已下载：整包下到一半失败时，
  /// 剩下的文件还得留在「还剩 N 个」里，不能被一次失败的批量操作抹掉。
  Future<CoursewareDownloadSummary> downloadAll(CoursewareNode node) async {
    _downloading.add(node.identity);
    _lastError = null;
    notifyListeners();
    try {
      final summary = await _repository.downloadTree(node);
      if (_disposed) return summary;
      _downloading.remove(node.identity);
      for (final id in summary.succeededIds) {
        _downloaded[id] = _batchSavedMark;
      }
      if (summary.succeededIds.isNotEmpty) {
        // 树本身也要重标一遍：顶部「还剩 N 份」和课程卡的数字都是从树里数的，
        // 只更新 _downloaded 的话列表上的文件是绿的、计数却没动。
        _roots = CoursewareTree.markDownloaded(_roots, {
          for (final id in summary.succeededIds) id: _batchSavedMark,
        });
      }
      if (summary.failed > 0) {
        _lastError = '${summary.failed} 个文件没下成功';
      }
      return summary;
    } catch (error) {
      if (_disposed) rethrow;
      _downloading.remove(node.identity);
      _lastError = '$error';
      notifyListeners();
      rethrow;
    }
  }

  Future<String> downloadTeachingCalendar(CoursewareNode courseNode) async {
    final key = 'calendar-${courseNode.identity}';
    _downloading.add(key);
    _lastError = null;
    notifyListeners();
    try {
      final path = await _repository.downloadTeachingCalendar(courseNode);
      if (_disposed) return path;
      _downloading.remove(key);
      return path;
    } catch (error) {
      if (_disposed) rethrow;
      _downloading.remove(key);
      _lastError = '$error';
      notifyListeners();
      rethrow;
    }
  }

  /// 整棵树里出现过的 identity。换树时用它裁掉过期的「已下载」标记。
  Set<String> get _knownIdentities =>
      CoursewareTree.indexOf(_roots).keys.toSet();

  @override
  void dispose() {
    _disposed = true;
    _downloading.clear();
    super.dispose();
  }
}
