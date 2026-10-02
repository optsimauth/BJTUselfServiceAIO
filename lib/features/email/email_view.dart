import 'email_models.dart';

/// 邮件列表的过滤 + 排序。纯函数，方便单测。
///
/// ponytail: 只作用在**已加载的这一页**上。要做全量筛选/排序就换成
/// `!mail:searchMessages` 的服务端参数（bundle 里已确认支持 read / flagType /
/// priority / attachType / dealings / pattern / order / desc）。
abstract final class MailView {
  /// 先过滤再排序，返回新的不可变列表。
  ///
  /// 置顶优先于用户选的排序字段：置顶组整组排在前面，组内仍按所选字段排。
  /// 列表请求已经带了 `topFirst:true`（服务端本来也置顶优先），但本地排序会把它
  /// 覆盖掉，所以这里必须再判一次。
  static List<MailSummary> apply(
    List<MailSummary> messages, {
    required MailFilter filter,
    required MailSort sort,
  }) {
    final kept = messages.where((m) => _matches(m, filter)).toList();
    kept.sort((a, b) {
      if (a.isTop != b.isTop) return a.isTop ? -1 : 1;
      return _compare(a, b, sort.field, sort.descending);
    });
    return List<MailSummary>.unmodifiable(kept);
  }

  /// 侧栏「搜索文件夹」：按名称过滤，查询词为空时原样返回。
  static List<MailFolder> foldersMatching(
    List<MailFolder> folders,
    String query,
  ) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return folders;
    return folders
        .where((f) => f.name.toLowerCase().contains(keyword))
        .toList(growable: false);
  }
}

bool _matches(MailSummary m, MailFilter f) {
  if (!_matchesRead(m, f.read)) return false;
  if (!_matchesFlag(m, f.flag)) return false;
  if (!_matchesPriority(m, f.priority)) return false;
  if (!_matchesAttachment(m, f.attachment)) return false;
  if (!_matchesDeal(m, f.deal)) return false;
  return _matchesQuery(m, f.query);
}

bool _matchesRead(MailSummary m, MailReadFilter f) => switch (f) {
  MailReadFilter.all => true,
  MailReadFilter.unread => !m.isRead,
  MailReadFilter.read => m.isRead,
};

bool _matchesFlag(MailSummary m, MailFlagFilter f) => switch (f) {
  MailFlagFilter.any => true,
  MailFlagFilter.flagged => m.isFlagged,
  MailFlagFilter.unflagged => !m.isFlagged,
};

bool _matchesPriority(MailSummary m, MailPriorityFilter f) =>
    f.priority == null || m.priority == f.priority;

bool _matchesAttachment(MailSummary m, MailAttachmentFilter f) => switch (f) {
  MailAttachmentFilter.any => true,
  MailAttachmentFilter.withAttachment => m.hasAttachments,
  MailAttachmentFilter.withoutAttachment => !m.hasAttachments,
};

bool _matchesDeal(MailSummary m, MailDealFilter f) => switch (f) {
  MailDealFilter.any => true,
  MailDealFilter.replied => m.replied,
  MailDealFilter.forwarded => m.forwarded,
};

/// 关键词：发件人、主题、摘要、收件人任一命中即可。
bool _matchesQuery(MailSummary m, String query) {
  final keyword = query.trim().toLowerCase();
  if (keyword.isEmpty) return true;
  if (m.sender.toLowerCase().contains(keyword)) return true;
  if (m.subject.toLowerCase().contains(keyword)) return true;
  if (m.preview.toLowerCase().contains(keyword)) return true;
  return m.recipients.any((r) => r.toLowerCase().contains(keyword));
}

/// 主键按方向排；主键相同时固定用 id 升序兜底，保证结果稳定。
///
/// 降序**不能**用 `list.reversed()` 实现：那会把兜底键也一起反过来，
/// 同一时间戳的邮件顺序就会跟升序时相反。
int _compare(MailSummary a, MailSummary b, MailSortField field, bool desc) {
  final primary = _compareBy(a, b, field);
  if (primary != 0) return desc ? -primary : primary;
  return a.id.compareTo(b.id);
}

/// 全部返回**升序**基线，方向由 [_compare] 统一套用。
int _compareBy(MailSummary a, MailSummary b, MailSortField field) =>
    switch (field) {
      MailSortField.time => _dateValue(a).compareTo(_dateValue(b)),
      MailSortField.sender => a.sender.toLowerCase().compareTo(
        b.sender.toLowerCase(),
      ),
      MailSortField.subject => a.subject.toLowerCase().compareTo(
        b.subject.toLowerCase(),
      ),
      MailSortField.size => a.sizeBytes.compareTo(b.sizeBytes),
    };

/// 列表接口给的是 `2026-03-05 09:10:00` 这类文本，原地换成可比较的整数。
/// 解析不了就退化成 0，靠次级键（id）保持稳定顺序。
int _dateValue(MailSummary m) =>
    DateTime.tryParse(m.dateText)?.millisecondsSinceEpoch ?? 0;
