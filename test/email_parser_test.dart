import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/features/email/email_models.dart';
import 'package:bjtuselfserviceaio/features/email/email_parser.dart';

void main() {
  test('列表解析未读状态、附件标记和发件箱收件人兜底', () {
    final page = MailParser.parseList('''
      {"code":"S_OK","total":2,"var":[
        {"id":"1","fid":1,"from":"老师 <teacher@example.test>","subject":"通知","summary":"请查看","receivedDate":"2026-08-29 09:10:01","flags":{"attached":true}},
        {"id":"2","fid":3,"to":["同学 <student@example.test>"],"subject":"资料","flags":{"read":true}}
      ]}
    ''');

    expect(page.totalCount, 2);
    expect(page.messages.first.isRead, isFalse);
    expect(page.messages.first.hasAttachments, isTrue);
    expect(page.messages.last.sender, '同学 <student@example.test>');
  });

  test('正文提取忽略 style/script 并保留表格结构', () {
    final blocks = MailParser.extractMailBlocks('''
      <style>.x{color:red}</style><p>第一段</p>
      <table><tr><th>科目</th><th>成绩</th></tr><tr><td>数学</td><td>90</td></tr></table>
      <script>alert(1)</script>
    ''');

    expect(blocks, hasLength(2));
    expect((blocks[0] as MailParagraph).text, '第一段');
    expect((blocks[1] as MailTable).rows, [
      ['科目', '成绩'],
      ['数学', '90'],
    ]);
  });

  test('写信草稿把 HTML 正文转换为纯文本', () {
    final draft = MailParser.parseDraft(
      '{"code":"S_OK","var":{"id":"draft-1","to":["a@example.test"],"subject":"主题","content":"<p>第一行</p><p>第二行</p>"}}',
      null,
    );

    expect(draft.id, 'draft-1');
    expect(draft.bodyText, '第一行\n第二行');
  });
}
