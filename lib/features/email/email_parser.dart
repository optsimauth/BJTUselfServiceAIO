import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'email_models.dart';

abstract final class MailParser {
  static MailboxPageResult parseList(String raw) {
    final root = _object(raw);
    _ensureSuccess(root);
    final items = root['var'];
    if (items is! List) throw const FormatException('邮件列表缺少 var');
    final messages = items.map(_parseSummary).toList(growable: false);
    final total =
        _asInt(root['total']) ?? _asInt(root['count']) ?? messages.length;
    return MailboxPageResult(totalCount: total, messages: messages);
  }

  static MailMessage parseMessage(String raw, String fallbackId) {
    final root = _object(raw);
    _ensureSuccess(root);
    final payload = _asMap(root['var']);
    final mail = _asMap(payload['mail']);
    final info = _asMap(payload['mailInfo']);
    final id = _asString(info['id']).trim().isEmpty
        ? fallbackId
        : _asString(info['id']);
    final html = _asString(_asMap(mail['mainPartData'])['content']);
    return MailMessage(
      id: id,
      folderId: _asInt(info['fid']) ?? 0,
      from: _asStrings(mail['from']),
      to: _asStrings(mail['to']),
      cc: _asStrings(mail['cc']),
      bcc: _asStrings(mail['bcc']),
      subject: _asString(mail['subject']),
      blocks: extractMailBlocks(html),
      dateText: _asString(info['sentDate']),
      attachments: _parseAttachments(mail['attachments']),
    );
  }

  static MailComposeDraft parseDraft(String raw, String? replyToMessageId) {
    final root = _object(raw);
    _ensureSuccess(root);
    final payload = _asMap(root['var']);
    final id = _asString(payload['id']);
    if (id.trim().isEmpty) throw const FormatException('草稿缺少 id');
    return MailComposeDraft(
      id: id,
      to: _asStrings(payload['to']).join(', '),
      cc: _asStrings(payload['cc']).join(', '),
      bcc: _asStrings(payload['bcc']).join(', '),
      subject: _asString(payload['subject']),
      bodyText: _plainText(_asString(payload['content'])),
      replyToMessageId: replyToMessageId,
      isReply: replyToMessageId != null,
    );
  }

  /// 服务端失败时把 `code` 带进异常。只说「失败」的话日志里看不出是会话过期
  /// （FA_INVALID_SESSION）、参数不对（FR_INVALID_REQUEST）还是真被拒。
  static void ensureCommandSuccess(String raw) {
    final root = _object(raw);
    final code = _asString(root['code']);
    if (code != 'S_OK') {
      final first = (root['messages'] as List?)?.firstOrNull;
      final summary = _asString(_asMap(first)['summary']);
      throw FormatException(
        '邮箱服务返回失败 code=$code${summary.isEmpty ? '' : ' $summary'}',
      );
    }
  }

  static List<MailContentBlock> extractMailBlocks(String source) {
    if (source.trim().isEmpty) return const [];
    final document = html_parser.parseFragment(source);
    final blocks = <MailContentBlock>[];
    final text = StringBuffer();
    void flush() {
      final value = _normalize(text.toString());
      if (value.isNotEmpty) blocks.add(MailParagraph(value));
      text.clear();
    }

    void visit(Node node) {
      if (node is Text) {
        text.write(node.data);
        return;
      }
      if (node is! Element) {
        node.nodes.forEach(visit);
        return;
      }
      final tag = node.localName?.toLowerCase() ?? '';
      if (const {
        'script',
        'style',
        'head',
        'meta',
        'link',
        'template',
        'title',
      }.contains(tag)) {
        return;
      }
      if (tag == 'table') {
        flush();
        final rows = _tableRows(node);
        if (rows.isNotEmpty) blocks.add(MailTable(rows));
        return;
      }
      if (tag == 'br') {
        text.write('\n');
        return;
      }
      node.nodes.forEach(visit);
      if (const {
        'p',
        'div',
        'section',
        'article',
        'li',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'blockquote',
      }.contains(tag)) {
        text.write('\n');
      }
    }

    document.nodes.forEach(visit);
    flush();
    return List<MailContentBlock>.unmodifiable(blocks);
  }

  static String _plainText(String source) => extractMailBlocks(source)
      .map(
        (block) => switch (block) {
          MailParagraph(:final text) => text,
          MailTable(:final rows) =>
            rows.map((row) => row.join('\t')).join('\n'),
        },
      )
      .join('\n');

  static List<List<String>> _tableRows(Element table) => [
    for (final row in table.querySelectorAll('tr'))
      [
        for (final cell in row.children.where(
          (cell) => cell.localName == 'td' || cell.localName == 'th',
        ))
          _normalize(cell.text),
      ],
  ].where((row) => row.any((cell) => cell.isNotEmpty)).toList(growable: false);

  /// 列表项 -> 摘要。红旗、置顶、待办、优先级都从这层读出来。
  static MailSummary _parseSummary(Object? raw) {
    final item = _asMap(raw);
    final from = _asStrings(item['from']);
    final to = _asStrings(item['to']);
    final flags = _asMap(item['flags']);
    return MailSummary(
      id: _required(_asString(item['id']), '邮件缺少 id'),
      folderId: _asInt(item['fid']) ?? 0,
      sender: (from.isEmpty ? to : from).join(', '),
      recipients: to,
      subject: _asString(item['subject']),
      preview: _plainText(_asString(item['summary'])),
      dateText: _asString(item['receivedDate']).isEmpty
          ? _asString(item['sentDate'])
          : _asString(item['receivedDate']),
      isRead: flags['read'] == true,
      hasAttachments:
          flags['attached'] == true || flags['inlineAttached'] == true,
      // 红旗是 label0（1 = 已标记），不是 flags 里的位。
      isFlagged: _asInt(item['label0']) == 1,
      isTop: flags['top'] == true,
      // 待办 = defer 有时间戳且 flags.deferHandle 打开。
      isTodo: _asInt(item['defer']) != null && flags['deferHandle'] == true,
      priority: MailPriority.fromWire(_asInt(item['priority'])),
      sizeBytes: _asInt(item['size']) ?? 0,
      replied: _hasDealing(item, 'replied'),
      forwarded: _hasDealing(item, 'forwarded'),
    );
  }

  /// `dealings` 可能是数组也可能是逗号分隔字符串，两种都认。
  static bool _hasDealing(Map<String, dynamic> item, String name) {
    final raw = item['dealings'];
    if (raw is List) return raw.any((e) => _asString(e) == name);
    return _asString(raw).split(',').map((e) => e.trim()).contains(name);
  }

  static List<MailAttachment> _parseAttachments(Object? raw) => [
    for (final item in raw is List ? raw : const [])
      if (_asString(_asMap(item)['name']).isNotEmpty ||
          _asString(_asMap(item)['fileName']).isNotEmpty)
        MailAttachment(
          id: _asString(_asMap(item)['id']).isEmpty
              ? null
              : _asString(_asMap(item)['id']),
          name: _asString(_asMap(item)['name']).isEmpty
              ? _asString(_asMap(item)['fileName'])
              : _asString(_asMap(item)['name']),
          sizeBytes:
              _asInt(_asMap(item)['size']) ?? _asInt(_asMap(item)['sizeBytes']),
          contentType: _asString(_asMap(item)['contentType']).isEmpty
              ? _asString(_asMap(item)['type'])
              : _asString(_asMap(item)['contentType']),
        ),
  ];

  static Map<String, dynamic> _object(String raw) {
    final decoded = jsonDecode(raw);
    return _asMap(decoded);
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

  static String _asString(Object? value) =>
      value is String ? value : value?.toString() ?? '';

  static int? _asInt(Object? value) =>
      value is int ? value : int.tryParse(_asString(value));

  static List<String> _asStrings(Object? value) => value is List
      ? value
            .map(_asString)
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : _asString(value).trim().isEmpty
      ? const []
      : [_asString(value)];

  static String _required(String value, String message) =>
      value.trim().isEmpty ? (throw FormatException(message)) : value;

  static void _ensureSuccess(Map<String, dynamic> root) {
    if (_asString(root['code']) != 'S_OK') {
      throw const FormatException('邮箱服务返回失败');
    }
  }

  static String _normalize(String value) => value
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}
