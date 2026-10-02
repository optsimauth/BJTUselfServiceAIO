import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/features/email/email_models.dart';
import 'package:bjtuselfserviceaio/features/email/email_view.dart';

MailSummary _mail(
  String id, {
  bool isRead = false,
  bool isFlagged = false,
  bool isTop = false,
  bool hasAttachments = false,
  bool replied = false,
  bool forwarded = false,
  MailPriority priority = MailPriority.normal,
  int sizeBytes = 0,
  String sender = 'a@example.test',
  String subject = '主题',
  String preview = '',
  String dateText = '2026-03-01 10:00:00',
  List<String> recipients = const [],
}) => MailSummary(
  id: id,
  folderId: 1,
  sender: sender,
  subject: subject,
  preview: preview,
  dateText: dateText,
  recipients: recipients,
  isRead: isRead,
  hasAttachments: hasAttachments,
  isFlagged: isFlagged,
  isTop: isTop,
  replied: replied,
  forwarded: forwarded,
  priority: priority,
  sizeBytes: sizeBytes,
);

const _noFilter = MailFilter();
const _defaultSort = MailSort();

List<String> _ids(List<MailSummary> list) =>
    list.map((m) => m.id).toList(growable: false);

void main() {
  group('过滤', () {
    test('默认过滤条件不过滤任何邮件', () {
      final all = [_mail('1'), _mail('2', isRead: true)];
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: _defaultSort)), [
        '1',
        '2',
      ]);
    });

    test('只保留未读', () {
      final all = [_mail('1'), _mail('2', isRead: true)];
      final result = MailView.apply(
        all,
        filter: const MailFilter(read: MailReadFilter.unread),
        sort: _defaultSort,
      );
      expect(_ids(result), ['1']);
    });

    test('只保留已读', () {
      final all = [_mail('1'), _mail('2', isRead: true)];
      final result = MailView.apply(
        all,
        filter: const MailFilter(read: MailReadFilter.read),
        sort: _defaultSort,
      );
      expect(_ids(result), ['2']);
    });

    test('已标记 / 未标记', () {
      final all = [_mail('1'), _mail('2', isFlagged: true)];
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(flag: MailFlagFilter.flagged),
            sort: _defaultSort,
          ),
        ),
        ['2'],
      );
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(flag: MailFlagFilter.unflagged),
            sort: _defaultSort,
          ),
        ),
        ['1'],
      );
    });

    test('按优先级筛选', () {
      final all = [
        _mail('1', priority: MailPriority.low),
        _mail('2', priority: MailPriority.high),
        _mail('3', priority: MailPriority.normal),
      ];
      final result = MailView.apply(
        all,
        filter: const MailFilter(priority: MailPriorityFilter.high),
        sort: _defaultSort,
      );
      expect(_ids(result), ['2']);
    });

    test('包含附件 / 不含附件', () {
      final all = [_mail('1'), _mail('2', hasAttachments: true)];
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(
              attachment: MailAttachmentFilter.withAttachment,
            ),
            sort: _defaultSort,
          ),
        ),
        ['2'],
      );
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(
              attachment: MailAttachmentFilter.withoutAttachment,
            ),
            sort: _defaultSort,
          ),
        ),
        ['1'],
      );
    });

    test('已回复 / 已转发', () {
      final all = [
        _mail('1', replied: true),
        _mail('2', forwarded: true),
        _mail('3'),
      ];
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(deal: MailDealFilter.replied),
            sort: _defaultSort,
          ),
        ),
        ['1'],
      );
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(deal: MailDealFilter.forwarded),
            sort: _defaultSort,
          ),
        ),
        ['2'],
      );
    });

    test('关键词命中发件人、主题、摘要或收件人任一即可', () {
      final all = [
        _mail('1', sender: 'alice@example.test'),
        _mail('2', subject: '关于选课'),
        _mail('3', preview: '本周课程安排'),
        _mail('4', recipients: const ['bob@example.test']),
        _mail('5'),
      ];
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(query: 'ALICE'),
            sort: _defaultSort,
          ),
        ),
        ['1'],
      );
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(query: '选课'),
            sort: _defaultSort,
          ),
        ),
        ['2'],
      );
      expect(
        _ids(
          MailView.apply(
            all,
            filter: const MailFilter(query: 'bob@'),
            sort: _defaultSort,
          ),
        ),
        ['4'],
      );
    });

    test('多条件同时生效时取交集', () {
      final all = [
        _mail('1'),
        _mail('2', isFlagged: true),
        _mail('3', isFlagged: true, hasAttachments: true),
      ];
      final result = MailView.apply(
        all,
        filter: const MailFilter(
          flag: MailFlagFilter.flagged,
          attachment: MailAttachmentFilter.withAttachment,
        ),
        sort: _defaultSort,
      );
      expect(_ids(result), ['3']);
    });
  });

  group('排序', () {
    test('按时间降序时最新在前', () {
      final all = [
        _mail('old', dateText: '2026-03-01 10:00:00'),
        _mail('new', dateText: '2026-03-05 10:00:00'),
      ];
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: _defaultSort)), [
        'new',
        'old',
      ]);
    });

    test('按时间升序时最早在前', () {
      final all = [
        _mail('old', dateText: '2026-03-01 10:00:00'),
        _mail('new', dateText: '2026-03-05 10:00:00'),
      ];
      const sort = MailSort(descending: false);
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: sort)), [
        'old',
        'new',
      ]);
    });

    test('按发件人升序', () {
      final all = [
        _mail('1', sender: 'carol@example.test'),
        _mail('2', sender: 'alice@example.test'),
      ];
      const sort = MailSort(field: MailSortField.sender, descending: false);
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: sort)), [
        '2',
        '1',
      ]);
    });

    test('按主题降序', () {
      final all = [_mail('1', subject: 'apple'), _mail('2', subject: 'banana')];
      const sort = MailSort(field: MailSortField.subject);
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: sort)), [
        '2',
        '1',
      ]);
    });

    test('按邮件大小降序', () {
      final all = [_mail('1', sizeBytes: 100), _mail('2', sizeBytes: 900)];
      const sort = MailSort(field: MailSortField.size);
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: sort)), [
        '2',
        '1',
      ]);
    });

    test('置顶邮件排在最前，不管时间新旧', () {
      final all = [
        _mail('1', dateText: '2026-03-05 09:00:00'),
        _mail('2', dateText: '2026-03-01 09:00:00', isTop: true),
        _mail('3', dateText: '2026-03-04 09:00:00'),
      ];
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: _defaultSort)), [
        '2',
        '1',
        '3',
      ]);
    });

    test('置顶组内部仍按所选字段排，非置顶组同理', () {
      final all = [
        _mail('old'),
        _mail('new'),
        _mail('p2', isTop: true),
        _mail('p1', isTop: true),
      ];
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: _defaultSort)), [
        'p1',
        'p2',
        'new',
        'old',
      ]);
    });

    test('置顶优先于用户选择的排序字段', () {
      final all = [
        _mail('a', sender: 'aaa@example.test'),
        _mail('z', sender: 'zzz@example.test', isTop: true),
      ];
      const sort = MailSort(field: MailSortField.sender, descending: false);
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: sort)), [
        'z',
        'a',
      ]);
    });
    test('排序键相同时按 id 兜底，结果稳定', () {
      final all = [_mail('b'), _mail('a')];
      expect(_ids(MailView.apply(all, filter: _noFilter, sort: _defaultSort)), [
        'a',
        'b',
      ]);
    });

    test('MailSort.flipped 只翻转方向不换字段', () {
      const sort = MailSort(field: MailSortField.subject);
      final flipped = sort.flipped();
      expect(flipped.field, MailSortField.subject);
      expect(flipped.descending, isFalse);
    });
  });

  group('文件夹搜索', () {
    const folders = defaultMailFolders;

    test('空查询返回全部', () {
      expect(MailView.foldersMatching(folders, ''), folders);
      expect(MailView.foldersMatching(folders, '   '), folders);
    });

    test('按名称包含匹配', () {
      expect(_folderNames(MailView.foldersMatching(folders, '收件')), ['收件箱']);
      expect(_folderNames(MailView.foldersMatching(folders, '待办')), ['待办邮件']);
    });

    test('无匹配时返回空列表', () {
      expect(MailView.foldersMatching(folders, '不存在'), isEmpty);
    });
  });
}

List<String> _folderNames(List<MailFolder> folders) =>
    folders.map((f) => f.name).toList(growable: false);
