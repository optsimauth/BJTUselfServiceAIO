import 'package:bjtuselfserviceaio/features/webview/web_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('只把外部协议交出去，网页内跳转全放行', () {
    // 网页内跳转
    expect(
      isWebviewNavigation(Uri.parse('https://mis.bjtu.edu.cn/home/')),
      isTrue,
    );
    expect(isWebviewNavigation(Uri.parse('http://aa.bjtu.edu.cn/x')), isTrue);
    // 教务系统菜单是相对地址，scheme 为空 —— 被拦掉就是「点了没反应」
    expect(isWebviewNavigation(Uri.parse('/module/module/28/')), isTrue);
    expect(isWebviewNavigation(Uri.parse('/login?next=/home/')), isTrue);
    expect(isWebviewNavigation(Uri.parse('#')), isTrue);
    // 外部协议
    expect(isWebviewNavigation(Uri.parse('tel:12345')), isFalse);
    expect(isWebviewNavigation(Uri.parse('mailto:a@bjtu.edu.cn')), isFalse);
    expect(
      isWebviewNavigation(Uri.parse('weixin://dl/business/?t=abc')),
      isFalse,
    );
    expect(isWebviewNavigation(Uri.parse('javascript:void(0)')), isFalse);
  });
}
