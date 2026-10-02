// 验证 CaptchaService 的 ONNX 链路：加载资产 -> 预处理 -> 推理 -> CTC 解码。
//
// 用合成图片跑通整条链，不校验识别内容（噪点图本来就认不出东西），
// 重点是资产键没写错、推理不抛异常、输出落在 charset 内。
//
// flutter test test/captcha_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:bjtuselfserviceaio/services/captcha/captcha_service.dart';

Uint8List _syntheticCaptcha() {
  final image = img.Image(width: 130, height: 42);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ONNX 模型能从资产加载并完成一次推理', () async {
    final captcha = CaptchaService();

    final expression = await captcha.recognizeExpression(_syntheticCaptcha());
    expect(expression, isNotEmpty);
    expect(expression, matches(RegExp(r'^[ 0-9+*=-]+$')));
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('solve 仍能解析算式', () {
    expect(CaptchaService().solve('1+2='), '3');
  });
}
