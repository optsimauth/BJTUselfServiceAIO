import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';
import '../../../core/utils/logger.dart';
import '../../../features/email/email_models.dart';
import '../../../features/email/email_parser.dart';

class EmailApi {
  EmailApi(this._request);

  static const Logger _log = Logger('EmailApi');
  static const String _mailHost = 'mail.bjtu.edu.cn';

  final RequestManager _request;
  String? _sid;

  void invalidateSession() {
    _sid = null;
  }

  Future<MailboxPageResult> listMessages({
    required int folderId,
    int start = 0,
    int limit = 20,
  }) async {
    final sid = await _sessionId();
    final raw = await _request.postJson(
      _jsonUrl(sid, 'mbox:listMessages'),
      query: null,
      body: {
        'start': start,
        'limit': limit,
        'mode': 'count',
        'order': 'date',
        'desc': true,
        'returnTotal': true,
        'returnTag': false,
        'summaryWindowSize': limit,
        'fid': folderId,
        'mboxa': '',
        'topFirst': true,
      },
      headers: _jsonHeaders,
    );
    return _guard(() => MailParser.parseList(raw));
  }

  /// 改邮件属性：已读/未读、红旗、优先级、置顶、待办。
  ///
  /// 服务端只认 `['id','fid','priority','label0','flags','defer']` 这几个字段，
  /// `attrs` 直接传这批键即可（参数结构取自 XT5 bundle 的
  /// `mbox:updateMessageInfos` 调用处）。
  ///
  /// 返回原始响应：`returnOriginalMsgInfos: true` 会把改完的邮件回显出来，
  /// 里面有没有 `defer` / `flags.deferHandle`，就是「服务端到底认没认这次
  /// 修改」的唯一证据（2026-10-02 排查待办邮件用）。
  Future<String> updateMessages(
    List<String> ids,
    Map<String, dynamic> attrs,
  ) async {
    if (ids.isEmpty) return '';
    final sid = await _sessionId();
    final raw = await _request.postJson(
      _jsonUrl(sid, 'mbox:updateMessageInfos'),
      body: {'ids': ids, 'attrs': attrs, 'returnOriginalMsgInfos': true},
      headers: _jsonHeaders,
    );
    _guard(() => MailParser.ensureCommandSuccess(raw));
    return raw;
  }

  /// 标/取消待办。手写请求体而不是走 [updateMessages]：
  /// `defer` 必须是 Coremail 的 `!!date 'yyyy-MM-dd HH:mm:ss'` 字面量
  /// （2026-10-02 抓网页版核对），不是合法 JSON，jsonEncode 编不出来。
  ///
  /// [deferOn] 为 null = 取消待办（只关 `deferHandle`，不动日期）。
  Future<String> updateTodo(List<String> ids, {DateTime? deferOn}) async {
    if (ids.isEmpty) return '';
    final sid = await _sessionId();
    final attrs = deferOn == null
        ? '{"flags":{"deferHandle":false}}'
        : '{"flags":{"deferHandle":true},"defer":${MailDefer.literal(deferOn)}}';
    final raw = await _request.postJson(
      _jsonUrl(sid, 'mbox:updateMessageInfos'),
      body:
          '{"mboxa":"","expandThreadMid":false,"ids":${jsonEncode(ids)},'
          '"attrs":$attrs,"returnOriginalMsgInfos":true}',
      headers: _jsonHeaders,
    );
    _guard(() => MailParser.ensureCommandSuccess(raw));
    return raw;
  }

  /// 移动邮件 = 把 `fid` 改成目标文件夹，走 [updateMessages] 同一个通道。
  ///
  /// 不用 `mbox:moveMessageArea`：那条路实测返回 `FS_UNKNOWN`（服务端内部错误，
  /// 2026-10-02 线上核对）—— 方法名服务端认得，body 结构却不合它的预期。
  /// 移动本来就只是改 `fid`，没有第二个接口可用。
  Future<void> moveMessages(List<String> ids, int targetFolderId) =>
      updateMessages(ids, {'fid': targetFolderId});

  Future<MailMessage> readMessage(String id) async {
    await _sessionId();
    final raw = await _request.postFormUrlEncoded(
      ApiConstants.mailReadMessageUrl,
      {'mid': id, 'mboxa': '', 'part': '', 'mailCipherPassword': ''},
      headers: _formHeaders,
    );
    return _guard(() => MailParser.parseMessage(raw, id));
  }

  Future<MailComposeDraft> beginCompose({String? replyToMessageId}) async {
    final sid = await _sessionId();
    final raw = await _request.postFormUrlEncoded(
      '${ApiConstants.mailComposeUrl}?sid=${Uri.encodeQueryComponent(sid)}',
      {
        'ctype': replyToMessageId == null ? 'normal' : 'reply',
        'mid': ?replyToMessageId,
        'mboxa': '',
      },
      headers: _formHeaders,
    );
    return _guard(() => MailParser.parseDraft(raw, replyToMessageId));
  }

  Future<void> sendMessage(MailComposeDraft draft) async {
    final sid = await _sessionId();
    final raw = await _request.postJson(
      _jsonUrl(sid, 'mbox:compose'),
      body: {
        'id': draft.id,
        'attrs': {
          'to': _recipients(draft.to),
          'cc': _recipients(draft.cc),
          'bcc': _recipients(draft.bcc),
          'subject': draft.subject.trim(),
          'isHtml': true,
          'content': _composeHtml(draft.bodyText),
          'attachments': [],
          'requestReadReceipt': false,
          'saveSentCopy': true,
        },
        'returnInfo': true,
        'action': 'deliver',
        if (draft.isReply) ...{
          'ctype': 'reply',
          'mid': draft.replyToMessageId ?? '',
          'mboxa': '',
        },
      },
      headers: _jsonHeaders,
    );
    _guard(() => MailParser.ensureCommandSuccess(raw));
  }

  Future<void> cancelCompose(String id) async {
    if (id.trim().isEmpty) return;
    final sid = await _sessionId();
    final raw = await _request.postJson(
      _jsonUrl(sid, 'mbox:cancelComposes'),
      body: {'ids': id},
      headers: _jsonHeaders,
    );
    _guard(() => MailParser.ensureCommandSuccess(raw));
  }

  Future<String> _sessionId() async {
    final cached = _sid;
    if (cached != null) return cached;
    final result = await _request.getTextWithFinalUri(
      ApiConstants.mailboxModuleUrl,
      headers: const {
        'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      },
    );
    final finalUri = result.finalUri;
    // 只记 host + path。sid 是会话凭证，绝不进日志，所以 query 一律不打。
    if (finalUri.host.toLowerCase() != _mailHost) {
      _log.w('邮箱入口没有落地到 mail：${finalUri.host}${finalUri.path}');
      throw const FormatException('邮箱登录会话已失效');
    }
    final sid = finalUri.queryParameters['sid'];
    if (sid == null || sid.isEmpty) {
      _log.w('邮箱入口已落地 mail，但最终地址上没有 sid：${finalUri.path}');
      throw const FormatException('邮箱会话缺少 sid');
    }
    _sid = sid;
    return sid;
  }

  /// Coremail 没给出 `S_OK` 包络（sid 过期时它返回 200 + 错误包络，
  /// 而不是 4xx），此时必须废掉缓存的 sid，否则每次重试都用同一个死 sid、
  /// 永远好不了 —— 参考实现 KMP `sessionExpired()` 正是这么做的。
  T _guard<T>(T Function() run) {
    try {
      return run();
    } on FormatException {
      _sid = null;
      rethrow;
    }
  }

  String _jsonUrl(String sid, String function) =>
      '${ApiConstants.mailJsonUrl}?sid=${Uri.encodeQueryComponent(sid)}&func=${Uri.encodeQueryComponent(function)}';

  static List<String> _recipients(String value) => value
      .split(RegExp(r'[,;，；\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  static String _composeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', '<br>');

  static const _jsonHeaders = {
    'Accept': 'text/x-json',
    'Content-Type': 'text/x-json; tz="Asia/Shanghai"',
    'X-Requested-With': 'XMLHttpRequest',
    'Referer': ApiConstants.mailIndexUrl,
  };

  static const _formHeaders = {
    'Accept': 'text/x-json',
    'X-Requested-With': 'XMLHttpRequest',
    'Referer': ApiConstants.mailIndexUrl,
  };
}
