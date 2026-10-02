import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dump output shape', () async {
    OrtEnv.instance.init();
    final raw = await rootBundle.load('assets/model.onnx');
    final session = OrtSession.fromBuffer(
      raw.buffer.asUint8List(),
      OrtSessionOptions(),
    );
    print('inputs : ${session.inputNames}');
    print('outputs: ${session.outputNames}');

    final image = img.Image(width: 130, height: 42);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final png = img.encodePng(image);
    final decoded = img.decodeImage(png)!;
    final resized = img.copyResize(decoded, width: 130, height: 42);

    final data = Float32List(3 * 42 * 130);
    var idx = 0;
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < 42; y++) {
        for (var x = 0; x < 130; x++) {
          final p = resized.getPixel(x, y);
          final num v = switch (c) {
            0 => p.r,
            1 => p.g,
            _ => p.b,
          };
          data[idx++] = v / 255.0;
        }
      }
    }

    final input = OrtValueTensor.createTensorWithDataList(data, <int>[
      1,
      3,
      42,
      130,
    ]);
    final opts = OrtRunOptions();
    final outputs = await session.runAsync(opts, {
      'input': input,
    }, session.outputNames);
    final value = outputs![0]!.value;
    print('value runtime type: ${value.runtimeType}');
    print('shape: ${_shape(value)}');
    print('value: $value');
  }, timeout: const Timeout(Duration(minutes: 1)));
}

String _shape(dynamic v) {
  final parts = <String>[];
  dynamic cur = v;
  while (cur is List) {
    parts.add('${cur.length}');
    cur = cur.isEmpty ? null : cur.first;
  }
  return '[${parts.join(', ')}]';
}
