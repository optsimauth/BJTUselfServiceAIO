import 'package:flutter/foundation.dart';

/// Coremail 优先级。`wire` 是 `mbox:updateMessageInfos` 里 priority 的取值。
enum MailPriority {
  low(1, '缓慢'),
  normal(2, '普通'),
  high(3, '紧急');

  const MailPriority(this.wire, this.label);

  final int wire;
  final String label;

  static MailPriority fromWire(int? value) => switch (value) {
    1 => MailPriority.low,
    3 => MailPriority.high,
    _ => MailPriority.normal,
  };
}

enum MailReadFilter {
  all('全部邮件'),
  unread('未读邮件'),
  read('已读邮件');

  const MailReadFilter(this.label);
  final String label;
}

enum MailFlagFilter {
  any('不按标记筛选'),
  flagged('已标记邮件'),
  unflagged('未标记邮件');

  const MailFlagFilter(this.label);
  final String label;
}

enum MailPriorityFilter {
  any('不按优先级筛选'),
  high('紧急'),
  normal('普通'),
  low('缓慢');

  const MailPriorityFilter(this.label);
  final String label;

  MailPriority? get priority => switch (this) {
    MailPriorityFilter.any => null,
    MailPriorityFilter.high => MailPriority.high,
    MailPriorityFilter.normal => MailPriority.normal,
    MailPriorityFilter.low => MailPriority.low,
  };
}

enum MailAttachmentFilter {
  any('不按附件筛选'),
  withAttachment('包含附件'),
  withoutAttachment('不含附件');

  const MailAttachmentFilter(this.label);
  final String label;
}

enum MailDealFilter {
  any('不按回复转发筛选'),
  replied('已回复'),
  forwarded('已转发');

  const MailDealFilter(this.label);
  final String label;
}

/// 过滤面板的全部条件。任一项为「不限」即不参与筛选。
@immutable
class MailFilter {
  const MailFilter({
    this.read = MailReadFilter.all,
    this.flag = MailFlagFilter.any,
    this.priority = MailPriorityFilter.any,
    this.attachment = MailAttachmentFilter.any,
    this.deal = MailDealFilter.any,
    this.query = '',
  });

  final MailReadFilter read;
  final MailFlagFilter flag;
  final MailPriorityFilter priority;
  final MailAttachmentFilter attachment;
  final MailDealFilter deal;
  final String query;

  bool get isEmpty =>
      read == MailReadFilter.all &&
      flag == MailFlagFilter.any &&
      priority == MailPriorityFilter.any &&
      attachment == MailAttachmentFilter.any &&
      deal == MailDealFilter.any &&
      query.trim().isEmpty;

  int get activeCount => [
    read != MailReadFilter.all,
    flag != MailFlagFilter.any,
    priority != MailPriorityFilter.any,
    attachment != MailAttachmentFilter.any,
    deal != MailDealFilter.any,
    query.trim().isNotEmpty,
  ].where((on) => on).length;

  MailFilter copyWith({
    MailReadFilter? read,
    MailFlagFilter? flag,
    MailPriorityFilter? priority,
    MailAttachmentFilter? attachment,
    MailDealFilter? deal,
    String? query,
  }) => MailFilter(
    read: read ?? this.read,
    flag: flag ?? this.flag,
    priority: priority ?? this.priority,
    attachment: attachment ?? this.attachment,
    deal: deal ?? this.deal,
    query: query ?? this.query,
  );
}

enum MailSortField {
  time('按时间'),
  sender('按发件人'),
  subject('按主题'),
  size('按邮件大小');

  const MailSortField(this.label);
  final String label;
}

/// 排序：字段 + 方向。默认时间从新到旧。
@immutable
class MailSort {
  const MailSort({this.field = MailSortField.time, this.descending = true});

  final MailSortField field;
  final bool descending;

  String get label => '${field.label}${descending ? '降序' : '升序'}';

  MailSort flipped() => MailSort(field: field, descending: !descending);
}

/// 对单封邮件可以执行的动作，全部走 `mbox:updateMessageInfos`。
enum MailAction {
  markUnread('标记未读'),
  markRead('标记已读'),
  flag('红旗标记'),
  unflag('取消标记'),
  top('置顶邮件'),
  untop('取消置顶'),
  todo('设为待办'),
  untodo('取消待办');

  const MailAction(this.label);
  final String label;
}

@immutable
class MailFolder {
  const MailFolder({
    required this.id,
    required this.name,
    this.icon = 'inbox',
    this.isGroup = false,
  });

  final int id;
  final String name;
  final String icon;

  final bool isGroup;

  /// 能不能当「移动到」的目标。
  ///
  /// 两个不能：[isGroup] 只是列表里的分组标题，没有 fid；「待办邮件」
  /// （[todoFolderId]）是 `defer` 标记出来的虚拟队列，改 `fid` 进不去，
  /// 服务端直接回 FA_FOLDER_NOT_FOUND（2026-10-02 线上核对）。
  bool get isMovableTarget => !isGroup && id != todoFolderId;
}

@immutable
class MailSummary {
  const MailSummary({
    required this.id,
    required this.folderId,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.dateText,
    this.recipients = const [],
    this.isRead = false,
    this.hasAttachments = false,
    this.isFlagged = false,
    this.isTop = false,
    this.isTodo = false,
    this.priority = MailPriority.normal,
    this.sizeBytes = 0,
    this.replied = false,
    this.forwarded = false,
  });

  final String id;
  final int folderId;
  final String sender;
  final String subject;
  final String preview;
  final String dateText;
  final List<String> recipients;
  final bool isRead;
  final bool hasAttachments;

  /// 红旗标记，对应服务端 `label0`。
  final bool isFlagged;

  /// 置顶，对应服务端 flags 里的置位。
  final bool isTop;

  /// 待办，对应服务端 `defer` + `flags.deferHandle`。
  final bool isTodo;

  final MailPriority priority;

  /// 用于「按邮件大小」排序；服务端没给时为 0。
  final int sizeBytes;
  final bool replied;
  final bool forwarded;

  MailSummary copyWith({
    bool? isRead,
    bool? isFlagged,
    bool? isTop,
    bool? isTodo,
    MailPriority? priority,
  }) => MailSummary(
    id: id,
    folderId: folderId,
    sender: sender,
    subject: subject,
    preview: preview,
    dateText: dateText,
    recipients: recipients,
    isRead: isRead ?? this.isRead,
    hasAttachments: hasAttachments,
    isFlagged: isFlagged ?? this.isFlagged,
    isTop: isTop ?? this.isTop,
    isTodo: isTodo ?? this.isTodo,
    priority: priority ?? this.priority,
    sizeBytes: sizeBytes,
    replied: replied,
    forwarded: forwarded,
  );
}

@immutable
class MailboxPageResult {
  const MailboxPageResult({required this.totalCount, required this.messages});

  final int totalCount;
  final List<MailSummary> messages;
}

@immutable
class MailAttachment {
  const MailAttachment({
    this.id,
    required this.name,
    this.sizeBytes,
    this.contentType,
  });

  final String? id;
  final String name;
  final int? sizeBytes;
  final String? contentType;
}

sealed class MailContentBlock {
  const MailContentBlock();
}

class MailParagraph extends MailContentBlock {
  const MailParagraph(this.text);

  final String text;
}

class MailTable extends MailContentBlock {
  const MailTable(this.rows);

  final List<List<String>> rows;
}

@immutable
class MailMessage {
  const MailMessage({
    required this.id,
    required this.folderId,
    required this.from,
    required this.to,
    required this.cc,
    required this.bcc,
    required this.subject,
    required this.blocks,
    required this.dateText,
    this.attachments = const [],
  });

  final String id;
  final int folderId;
  final List<String> from;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final List<MailContentBlock> blocks;
  final String dateText;
  final List<MailAttachment> attachments;
}

@immutable
class MailComposeDraft {
  const MailComposeDraft({
    required this.id,
    this.to = '',
    this.cc = '',
    this.bcc = '',
    this.subject = '',
    this.bodyText = '',
    this.replyToMessageId,
    this.isReply = false,
  });

  final String id;
  final String to;
  final String cc;
  final String bcc;
  final String subject;
  final String bodyText;
  final String? replyToMessageId;
  final bool isReply;

  MailComposeDraft copyWith({
    String? to,
    String? cc,
    String? bcc,
    String? subject,
    String? bodyText,
  }) => MailComposeDraft(
    id: id,
    to: to ?? this.to,
    cc: cc ?? this.cc,
    bcc: bcc ?? this.bcc,
    subject: subject ?? this.subject,
    bodyText: bodyText ?? this.bodyText,
    replyToMessageId: replyToMessageId,
    isReply: isReply,
  );
}

/// 侧栏主列表。
///
/// fid 取自 Coremail XT5：1 收件箱、-5 待办邮件（defer 队列）、2 草稿箱、3 已发送、
/// 4 已删除、5 垃圾邮件、6 病毒邮件。
///
/// 「其他文件夹」是自建文件夹的分组标题，XT5 没有对应 fid，所以标记为 [MailFolder.isGroup]。
const defaultMailFolders = <MailFolder>[
  MailFolder(id: 1, name: '收件箱', icon: 'inbox'),
  MailFolder(id: -5, name: '待办邮件', icon: 'flag'),
  MailFolder(id: 2, name: '草稿箱', icon: 'drafts'),
  MailFolder(id: 3, name: '已发送', icon: 'send'),
  MailFolder(id: 4, name: '已删除', icon: 'delete'),
  MailFolder(id: 5, name: '垃圾邮件', icon: 'spam'),
  MailFolder(id: 6, name: '病毒邮件', icon: 'virus'),
  MailFolder(id: 0, name: '其他文件夹', icon: 'other', isGroup: true),
];

/// 「移动到」的可选目标。不进侧栏，只在移动菜单里出现。
///
/// 服务端把「移到 fid=4」当删除处理，所以已删除必须是移动目标。
///
/// **不含待办邮件（fid -5）**：它不是真文件夹，是 `defer` 标记出来的虚拟队列，
/// 改 `fid` 进不去（线上实测 `FS_UNKNOWN`，2026-10-02）。标待办走操作菜单
/// 顶部那个 toggle —— `defer` + `flags.deferHandle`，另一条通道。
const moveTargetFolders = <MailFolder>[
  MailFolder(id: 1, name: '收件箱'),
  MailFolder(id: 2, name: '草稿箱'),
  MailFolder(id: 3, name: '已发送'),
  MailFolder(id: 4, name: '已删除'),
  MailFolder(id: 5, name: '垃圾邮件'),
  MailFolder(id: 6, name: '病毒邮件'),
];

const trashFolderId = 4;

/// 「待办邮件」。不是真文件夹：它由每封邮件的 `defer` + `flags.deferHandle`
/// 标记出来，服务端没有对应 fid，往里「移动」一定失败。
const todoFolderId = -5;

/// 待办日期的字面量。单独放一层是为了能直接跑单元测试。
///
/// 网页版标待办时 `defer` 发的不是数字也不是字符串，是 Coremail 自己的
/// 日期字面量 `!!date 'yyyy-MM-dd HH:mm:ss'`（2026-10-02 抓包核对）。传数字或
/// ISO 字符串一律回 `FS_UNKNOWN`，而且错误码里看不出是哪错了，所以这层只
/// 认这一个格式。
abstract final class MailDefer {
  static String literal(DateTime when) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${when.year}-${two(when.month)}-${two(when.day)} '
        '${two(when.hour)}:${two(when.minute)}:${two(when.second)}';
    return "!!date '$date'";
  }
}
