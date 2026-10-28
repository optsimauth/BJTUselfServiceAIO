import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('数据层不得反向依赖页面功能目录', () {
    final violations = <String>[];
    for (final file in Directory(
      'lib/data',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final imports = file.readAsLinesSync().where(
        (line) => line.startsWith('import ') || line.startsWith('export '),
      );
      if (imports.any((line) => line.contains('/features/'))) {
        violations.add(file.path);
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '共享模型/解析器应放在 data，下层不能导入 features：$violations',
    );
  });
}
