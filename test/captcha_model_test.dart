import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/services/captcha/captcha_service.dart';

/// 输入验证码图片字节，输出 ONNX 识别出的算式字符串。
Future<String> recognizeCaptcha(Uint8List image) {
  return CaptchaService().recognizeExpression(image);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('识别项目根目录的 captcha.png', () async {
    final image = await File('captcha.png').readAsBytes();
    final result = await recognizeCaptcha(image);

    print('captcha.png 识别结果: $result');
    expect(result, isNotEmpty);
    expect(result, matches(RegExp(r'^[ 0-9+*=-]+$')));
  }, timeout: const Timeout(Duration(minutes: 1)));
}
