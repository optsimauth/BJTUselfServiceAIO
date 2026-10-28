import 'package:bjtuselfserviceaio/data/remote/parsers/status_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('状态接口解析', () {
    test('学校原样返回三个字符串', () {
      final status = StatusParser.parse(
        '{"net_fee":"0.00","ecard_yuer":"23.50","newmail_count":"3"}',
      );
      expect(status.ecardBalance, '23.50');
      expect(status.netBalance, '0.00');
      expect(status.unreadMail, 3);
    });

    test('数字类型也认（学校有时候不带引号）', () {
      final status = StatusParser.parse(
        '{"net_fee":12.3,"ecard_yuer":8,"newmail_count":0}',
      );
      expect(status.netBalance, '12.3');
      expect(status.ecardBalance, '8');
      expect(status.unreadMail, 0);
    });

    test('只给部分字段也算成功，缺的就是 null', () {
      final status = StatusParser.parse('{"ecard_yuer":"15.00"}');
      expect(status.ecardBalance, '15.00');
      expect(status.netBalance, isNull);
      expect(status.unreadMail, isNull);
      expect(status.hasAny, isTrue);
    });

    test('登录失效返回登录页 HTML 时必须报错，不能当成余额 0', () {
      expect(
        () => StatusParser.parse('<!DOCTYPE html><html><body>登录</body></html>'),
        throwsFormatException,
      );
    });

    test('JSON 里没有可用字段也报错', () {
      expect(
        () => StatusParser.parse('{"code":0}'),
        throwsFormatException,
      );
    });

    test('空响应不猜', () {
      expect(() => StatusParser.parse('   '), throwsFormatException);
    });
  });

  group('余额提醒阈值', () {
    test('校园卡低于 20 元提醒', () {
      expect(
        StatusParser.parse('{"ecard_yuer":"19.99"}').ecardIsLow,
        isTrue,
      );
      expect(
        StatusParser.parse('{"ecard_yuer":"20.00"}').ecardIsLow,
        isFalse,
      );
    });

    test('校园网 0 / 0.00 都算没网，非数字不算', () {
      expect(StatusParser.parse('{"net_fee":"0"}').netIsEmpty, isTrue);
      expect(StatusParser.parse('{"net_fee":"0.00"}').netIsEmpty, isTrue);
      expect(StatusParser.parse('{"net_fee":"1.5"}').netIsEmpty, isFalse);
      expect(StatusParser.parse('{"net_fee":"未知"}').netIsEmpty, isFalse);
    });
  });
}
