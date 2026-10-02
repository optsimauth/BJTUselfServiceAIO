// 待办邮件的 defer 格式：网页版发的是 Coremail 自己的日期字面量
// `!!date 'yyyy-MM-dd HH:mm:ss'`，不是数字也不是 ISO 字符串。
// 传错格式服务端只回 FS_UNKNOWN，错误码里看不出哪错了，所以把格式钉死在这。
import 'package:bjtuselfserviceaio/features/email/email_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('日期字面量就是网页版那一串', () {
    expect(
      MailDefer.literal(DateTime(2026, 10, 3)),
      "!!date '2026-10-03 00:00:00'",
    );
  });

  test('月/日/时/分/秒都补零，宽度不对服务端就当垃圾解析', () {
    expect(
      MailDefer.literal(DateTime(2026, 1, 2, 3, 4, 5)),
      "!!date '2026-01-02 03:04:05'",
    );
  });

  test('带时刻也能发（待办不一定总是零点）', () {
    expect(
      MailDefer.literal(DateTime(2026, 12, 31, 23, 59, 59)),
      "!!date '2026-12-31 23:59:59'",
    );
  });
}