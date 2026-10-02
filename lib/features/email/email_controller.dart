import 'package:flutter/foundation.dart';

import '../../core/model/async_state.dart';
import '../../core/utils/logger.dart';
import '../../data/remote/api/email_api.dart';
import 'email_models.dart';
import 'email_view.dart';

class EmailViewState {
  const EmailViewState({required this.messages, required this.totalCount});

  final List<MailSummary> messages;
  final int totalCount;
}

class EmailController extends ChangeNotifier {
  EmailController({required EmailApi api}) : _api = api;

  static const Logger _log = Logger('EmailController');

  final EmailApi _api;
  AsyncState<EmailViewState> _state = AsyncState<EmailViewState>.idle();
  bool _disposed = false;
  int _folderId = 1;
  bool _hasMore = false;
  bool _loadingMore = false;

  /// 正在拉列表。换文件夹 / 下拉刷新都算。
  bool _refreshing = false;
  MailMessage? _message;
  MailComposeDraft? _draft;
  MailFilter _filter = const MailFilter();
  MailSort _sort = const MailSort();
  String _folderQuery = '';
  final Set<String> _selection = {};

  AsyncState<EmailViewState> get state => _state;
  int get folderId => _folderId;
  MailMessage? get message => _message;
  MailComposeDraft? get draft => _draft;
  bool get loadingMore => _loadingMore;

  /// 正在拉列表（首屏 / 换文件夹 / 下拉刷新）。
  ///
  /// 界面用它做**列表区顶部**那条进度条 —— 不盖遮罩，盖遮罩就是那一下灰闪。
  bool get loading => _refreshing;

  /// 是否已经拿到过一次结果。
  ///
  /// 用来区分两种等待：没拿过 = 首屏（列表区本来就是空的，居中转圈）；
  /// 拿过了 = 换文件夹（内容原地保留，只在顶边挂进度条）。
  bool get hasData => _state.valueOrNull != null;
  bool get hasMore => _hasMore;
  List<MailFolder> get folders => defaultMailFolders;

  /// 当前文件夹名，找不到时回退到第一个。
  String get currentFolderName => folders
      .firstWhere((f) => f.id == _folderId, orElse: () => folders.first)
      .name;

  MailFilter get filter => _filter;
  MailSort get sort => _sort;
  String get folderQuery => _folderQuery;
  Set<String> get selection => Set.unmodifiable(_selection);
  bool get selecting => _selection.isNotEmpty;

  /// 侧栏文件夹，受「搜索文件夹」影响。
  List<MailFolder> get visibleFolders =>
      MailView.foldersMatching(defaultMailFolders, _folderQuery);

  /// 列表：已经过过滤 + 排序。
  List<MailSummary> get visibleMessages {
    final data = _state.valueOrNull;
    if (data == null) return const [];
    return MailView.apply(data.messages, filter: _filter, sort: _sort);
  }

  int get unreadCount => visibleMessages.where((m) => !m.isRead).length;

  /// 拉一次列表。
  ///
  /// 只发一次通知：开始时把 [loading] 置上，结束时用结果覆盖。
  /// 已经有数据时**不**把 state 打回 loading —— 那一整段会让界面把右侧列表
  /// 换成空白再换回来，看着就是「点一下文件夹闪一下」。
  Future<void> refresh() async {
    _refreshing = true;
    _selection.clear();
    _message = null;
    if (_state.valueOrNull == null) {
      // 首屏：还没有任何内容，state 就该是 loading（列表区本来是空的）。
      _state = AsyncState<EmailViewState>.loading();
    }
    _notify();
    try {
      final result = await _api.listMessages(folderId: _folderId);
      _hasMore = result.messages.length < result.totalCount;
      _state = AsyncState<EmailViewState>.data(
        EmailViewState(
          messages: result.messages,
          totalCount: result.totalCount,
        ),
      );
    } catch (error) {
      // 界面上只给一句通用文案，但真因必须留痕：Format=包络/会话，
      // Network=网络。release 下 warn 级仍会进 logcat。
      _log.w('邮箱刷新失败', error);
      _state = AsyncState<EmailViewState>.error(error);
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> selectFolder(int id) async {
    if (_folderId == id) return;
    _folderId = id;
    _selection.clear();
    _filter = const MailFilter();
    await refresh();
  }

  void searchFolders(String query) {
    _folderQuery = query;
    _notify();
  }

  void updateFilter(MailFilter next) {
    _filter = next;
    _notify();
  }

  void clearFilter() => updateFilter(const MailFilter());

  void updateSort(MailSort next) {
    _sort = next;
    _notify();
  }

  void flipSortDirection() {
    _sort = _sort.flipped();
    _notify();
  }

  void toggleSelect(String id) {
    if (!_selection.remove(id)) _selection.add(id);
    _notify();
  }

  void clearSelection() {
    if (_selection.isEmpty) return;
    _selection.clear();
    _notify();
  }

  Future<void> loadMore() async {
    final current = _state.valueOrNull;
    if (_loadingMore || !_hasMore || current == null || _disposed) return;
    _loadingMore = true;
    _notify();
    try {
      final result = await _api.listMessages(
        folderId: _folderId,
        start: current.messages.length,
      );
      _hasMore =
          current.messages.length + result.messages.length <
              result.totalCount &&
          result.messages.isNotEmpty;
      _appendMessages(result.messages, result.totalCount);
    } catch (_) {
      // 保留已有列表，仅恢复「加载更多」按钮。
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  Future<MailMessage?> openMessage(MailSummary summary) async {
    try {
      final message = await _api.readMessage(summary.id);
      _message = message;
      if (!summary.isRead) {
        _applyLocal(summary.id, (m) => m.copyWith(isRead: true));
        await _api.updateMessages([summary.id], _readAttrs(true));
      }
      _notify();
      return message;
    } catch (error) {
      _log.w('打开邮件失败', error);
      return null;
    }
  }

  /// 对一封邮件执行动作。本地先改、失败回滚。
  ///
  /// 标待办用 [todoAt] 指定待办到哪一天（默认明天零点）。
  Future<bool> runAction(
    MailSummary summary,
    MailAction action, {
    DateTime? todoAt,
  }) async {
    final patch = _patchFor(action);
    if (patch == null) return false;
    final previous = summary;
    _applyLocal(summary.id, patch);
    try {
      final raw = await _send([summary.id], action, todoAt: todoAt);
      // 待办邮件服务端回 S_OK 就算成功，但到底有没有把 defer 落到邮件上，
      // 只有 returnOriginalMsgInfos 回显的那份能作证。截一段进日志，
      // 下次再对不上时不用瞎猜（2026-10-02）。
      if (action == MailAction.todo || action == MailAction.untodo) {
        _log.i(
          '待办邮件回显：${raw.length > 600 ? '${raw.substring(0, 600)}…' : raw}',
        );
      }
      return true;
    } catch (error) {
      // 用 error 而不是 w：只有 error 落盘，写操作失败必须能事后翻日志。
      // 之前这里是 warn，日志页默认不显示 —— 待办邮件那次失败就因此查不到
      // 服务端给的错误码（2026-10-02）。
      _log.e('执行邮件动作失败 action=${action.name}', error);
      _applyLocal(previous.id, (m) => previous);
      return false;
    }
  }

  /// 默认待办日：明天零点。没选日期时用它。
  static DateTime get _defaultTodoAt {
    final t = DateTime.now().add(const Duration(days: 1));
    return DateTime(t.year, t.month, t.day);
  }

  /// 动作 -> 服务端请求。待办走 [EmailApi.updateTodo]：它的 `defer` 是
  /// `!!date` 字面量，jsonEncode 编不出来（2026-10-02 抓包核对）。
  Future<String> _send(
    List<String> ids,
    MailAction action, {
    DateTime? todoAt,
  }) => switch (action) {
    MailAction.todo =>
      _api.updateTodo(ids, deferOn: todoAt ?? _defaultTodoAt),
    MailAction.untodo => _api.updateTodo(ids),
    _ => _api.updateMessages(ids, _attrsFor(action)),
  };

  /// 批量动作：先本地改，再发一次请求；失败整批回滚。
  Future<bool> runActionOnSelection(MailAction action) async {
    final ids = _selection.toList();
    if (ids.isEmpty) return false;
    final patch = _patchFor(action);
    if (patch == null) return false;
    final backup = <String, MailSummary>{for (final id in ids) id: ?_find(id)};
    for (final id in ids) {
      _applyLocal(id, patch);
    }
    try {
      await _send(ids, action);
      _selection.clear();
      _notify();
      return true;
    } catch (error) {
      _log.w('批量执行邮件动作失败', error);
      for (final entry in backup.entries) {
        _applyLocal(entry.key, (_) => entry.value);
      }
      return false;
    }
  }

  /// 移动（含「移到已删除」= 删除）。移动单封邮件。
  ///
  /// 两道本地闸门，省得白跑一趟再吃服务端一句 FA_FOLDER_NOT_FOUND：
  /// 1. 目标不是真文件夹（「待办邮件」虚拟队列 / 「其他文件夹」分组）；
  /// 2. 源就是待办队列 —— 里面的邮件靠 `defer` 标记，没有 fid 可改，
  ///    要移出去得先「取消待办」。
  Future<bool> moveMessage(String id, int targetFolderId) async {
    if (!_canMove(targetFolderId)) return false;
    try {
      await _api.moveMessages([id], targetFolderId);
      await refresh();
      return true;
    } catch (error) {
      // 用 error 而不是 w：只有 error 落盘，写操作失败必须能事后翻日志。
      _log.e('移动邮件失败', error);
      return false;
    }
  }

  Future<bool> moveSelection(int targetFolderId) async {
    final ids = _selection.toList();
    if (ids.isEmpty) return false;
    if (!_canMove(targetFolderId)) return false;
    try {
      await _api.moveMessages(ids, targetFolderId);
      await refresh();
      return true;
    } catch (error) {
      // 用 error 而不是 w：只有 error 落盘，写操作失败必须能事后翻日志。
      _log.e('移动邮件失败', error);
      return false;
    }
  }

  /// 服务端认不认这次移动。false 时根本不发请求，只记一条 warn。
  bool _canMove(int targetFolderId) {
    final target = folders
        .where((folder) => folder.id == targetFolderId)
        .firstOrNull;
    if (target != null && !target.isMovableTarget) {
      _log.w('移动被拦下：${target.name} 不是可移动的目标文件夹');
      return false;
    }
    if (_folderId == todoFolderId) {
      _log.w('移动被拦下：待办邮件是 defer 虚拟队列，先取消待办再移动');
      return false;
    }
    return true;
  }

  Future<MailComposeDraft?> startCompose({String? replyToMessageId}) async {
    _draft = null;
    _notify();
    try {
      _draft = await _api.beginCompose(replyToMessageId: replyToMessageId);
      _notify();
      return _draft;
    } catch (error) {
      _log.w('进入写信页失败', error);
      return null;
    }
  }

  void updateDraft(MailComposeDraft draft) {
    _draft = draft;
    _notify();
  }

  Future<bool> sendDraft() async {
    final draft = _draft;
    if (draft == null) return false;
    try {
      await _api.sendMessage(draft);
      _draft = null;
      _notify();
      return true;
    } catch (error) {
      _log.w('发送邮件失败', error);
      return false;
    }
  }

  Future<void> cancelDraft() async {
    final id = _draft?.id;
    _draft = null;
    _notify();
    if (id != null) {
      try {
        await _api.cancelCompose(id);
      } catch (_) {
        // 页面已经退出，服务器草稿清理尽力而为。
      }
    }
  }

  void clearMessage() {
    _message = null;
    _notify();
  }

  // ---- 内部：动作 -> 本地补丁 / 服务端 attrs ----

  /// 动作对列表项的本地影响。null 表示这个动作不改本地数据。
  static MailSummary Function(MailSummary)? _patchFor(MailAction action) =>
      switch (action) {
        MailAction.markRead => (m) => m.copyWith(isRead: true),
        MailAction.markUnread => (m) => m.copyWith(isRead: false),
        MailAction.flag => (m) => m.copyWith(isFlagged: true),
        MailAction.unflag => (m) => m.copyWith(isFlagged: false),
        MailAction.top => (m) => m.copyWith(isTop: true),
        MailAction.untop => (m) => m.copyWith(isTop: false),
        MailAction.todo => (m) => m.copyWith(isTodo: true),
        MailAction.untodo => (m) => m.copyWith(isTodo: false),
      };

  /// 动作发给 `mbox:updateMessageInfos` 的 attrs。待办不在这里 ——
  /// 见 [_send]。
  static Map<String, dynamic> _attrsFor(MailAction action) => switch (action) {
    MailAction.markRead => _readAttrs(true),
    MailAction.markUnread => _readAttrs(false),
    MailAction.flag => {'label0': 1},
    MailAction.unflag => {'label0': 0},
    MailAction.top => {
      'flags': {'top': true},
    },
    MailAction.untop => {
      'flags': {'top': false},
    },
    MailAction.todo || MailAction.untodo =>
      throw StateError('待办动作走 EmailApi.updateTodo'),
  };

  static Map<String, dynamic> _readAttrs(bool read) => {
    'flags': {'read': read},
  };

  void _appendMessages(List<MailSummary> incoming, int total) {
    final current = _state.valueOrNull;
    if (current == null) return;
    final seen = current.messages.map((m) => m.id).toSet();
    _setState(
      AsyncState<EmailViewState>.data(
        EmailViewState(
          messages: [
            ...current.messages,
            ...incoming.where((m) => seen.add(m.id)),
          ],
          totalCount: total,
        ),
      ),
    );
  }

  MailSummary? _find(String id) {
    final data = _state.valueOrNull;
    if (data == null) return null;
    for (final m in data.messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _applyLocal(String id, MailSummary Function(MailSummary) patch) {
    final data = _state.valueOrNull;
    if (data == null) return;
    var changed = false;
    final next = [
      for (final m in data.messages)
        if (m.id == id)
          () {
            changed = true;
            return patch(m);
          }()
        else
          m,
    ];
    if (!changed) return;
    _state = AsyncState<EmailViewState>.data(
      EmailViewState(messages: next, totalCount: data.totalCount),
    );
    _notify();
  }

  void _setState(AsyncState<EmailViewState> value) {
    if (_disposed) return;
    _state = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
