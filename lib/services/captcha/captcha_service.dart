
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../../core/utils/logger.dart';

class CaptchaException implements Exception {
  const CaptchaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 验证码识别：图片字节 -> ONNX 推理 -> 算式字符串。
///
/// ONNX 模型直接在 Dart 侧运行，所有平台共用这一套实现。
class CaptchaService {
  CaptchaService();

  static const Logger _log = Logger('CaptchaService');

  /// pubspec.yaml 里注册的资产键（不是文件系统路径）。
  static const String _assetPath = 'assets/model.onnx';

  // 与模型导出时的输入尺寸一致：Tensor.fromBlob(data, new long[]{1, 3, 42, 130})
  static const int _inputW = 130;
  static const int _inputH = 42;
  static const int _timeSteps = 8;
  static const int _numClasses = 15;

  static const String _inputName = 'input';
  static const String _outputName = 'output';

  static const List<String> _charset = <String>[
    ' ',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '+',
    '-',
    '*',
    '=',
  ];

  static bool _envReady = false;

  /// 模型只加载一次；首次识别时才初始化，避免拖慢启动。
  Future<OrtSession>? _session;

  Future<String> recognizeExpression(Uint8List image) async {
    _log.d('识别验证码 ${image.length} 字节');
    final session = await _openSession();
    final expression = await _recognize(session, image);
    _log.d('ONNX 识别 -> $expression');
    if (kDebugMode) debugPrint('ONNX 识别 -> $expression');
    if (expression.isEmpty) throw const CaptchaException('验证码识别为空');
    return expression;
  }

  String? solve(String expression) {
    final match = RegExp(r'^(\d+)\s*([+\-*])\s*(\d+)\s*=?\s*$')
        .firstMatch(expression);
    if (match == null) return null;

    final left = int.parse(match.group(1)!);
    final right = int.parse(match.group(3)!);
    return switch (match.group(2)) {
      '+' => '${left + right}',
      '-' => '${left - right}',
      '*' => '${left * right}',
      _ => null,
    };
  }

  Future<OrtSession> _openSession() async {
    try {
      return await (_session ??= _loadSession());
    } catch (_) {
      // 加载失败时丢掉缓存的 Future，下次识别还能重试。
      _session = null;
      rethrow;
    }
  }

  static Future<OrtSession> _loadSession() async {
    if (!_envReady) {
      OrtEnv.instance.init();
      _envReady = true;
    }
    final raw = await rootBundle.load(_assetPath);
    return OrtSession.fromBuffer(raw.buffer.asUint8List(), OrtSessionOptions());
  }

  Future<String> _recognize(OrtSession session, Uint8List image) async {
    final input = OrtValueTensor.createTensorWithDataList(
      _preprocess(image),
      <int>[1, 3, _inputH, _inputW],
    );
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      // 同步推理而不是 runAsync：输入只有 1x3x42x130，阻塞 UI 线程几毫秒；
      // runAsync 会另开 isolate 并把 ORT 的裸指针跨 isolate 传，没必要。
      outputs = session.run(
        runOptions,
        <String, OrtValue>{_inputName: input},
        <String>[_outputName],
      );
      return _decode(_logits(outputs));
    } finally {
      input.release();
      outputs?.forEach((o) => o?.release());
      runOptions.release();
    }
  }

  /// 模型输出 [8, 1, 15]，去掉每个时间步的 batch 维后得到 [8, 15]。
  List<dynamic> _logits(List<OrtValue?>? outputs) {
    if (outputs == null || outputs.isEmpty || outputs[0] == null) {
      throw const CaptchaException('ONNX 推理无输出');
    }
    final value = outputs[0]!.value;
    if (value is! List || value.length != _timeSteps) {
      throw const CaptchaException('ONNX 输出形状不符');
    }
    return value.map((step) {
      if (step is! List || step.length != 1 || step[0] is! List) {
        throw const CaptchaException('ONNX 输出形状不符');
      }
      final row = step[0] as List;
      if (row.length != _numClasses) {
        throw const CaptchaException('ONNX 输出形状不符');
      }
      return row;
    }).toList();
  }

  /// Uint8List(原图) -> Float32List(NCHW, /255)
  Float32List _preprocess(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const CaptchaException('图片解码失败');

    final resized = img.copyResize(
      decoded,
      width: _inputW,
      height: _inputH,
      interpolation: img.Interpolation.linear,
    );

    // CHW 排列
    final out = Float32List(3 * _inputH * _inputW);
    int idx = 0;
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < _inputH; y++) {
        for (int x = 0; x < _inputW; x++) {
          final p = resized.getPixel(x, y);
          final num v = switch (c) {
            0 => p.r,
            1 => p.g,
            _ => p.b,
          };
          out[idx++] = v / 255.0;
        }
      }
    }
    return out;
  }

  /// CTC 贪心解码：逐帧取 argmax，去掉重复与 blank。
  String _decode(List<dynamic> timeMajor) {
    final buf = StringBuffer();
    int prev = 0;
    for (int t = 0; t < _timeSteps; t++) {
      final row = timeMajor[t] as List;
      int maxIdx = 0;
      double maxVal = double.negativeInfinity;
      for (int j = 0; j < _numClasses; j++) {
        final v = (row[j] as num).toDouble();
        if (v > maxVal) {
          maxVal = v;
          maxIdx = j;
        }
      }
      if ((t == 0 || maxIdx != prev) && maxIdx != 0) {
        buf.write(_charset[maxIdx]);
      }
      prev = maxIdx;
    }
    return buf.toString();
  }
}
