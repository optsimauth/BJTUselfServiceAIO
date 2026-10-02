import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 设计 token 守卫。
///
/// 规则来自 docs/DESIGN_SYSTEM.md：间距 / 圆角 / 字号 / 颜色都必须走
/// `lib/shared/theme/` 里的 token，页面里只允许出现 token 名。这样「同一个 app
/// 两种间距」这种问题在 code review 之前就被挡掉了。
///
/// 白名单只放两类：
/// 1. token 层自己（定义 token 的地方当然有裸数字）；
/// 2. 注释里的示例（`/// 8:00~9:50` 之类），所以先去掉注释再扫。
void main() {
  final files = _featureFiles();

  test('lib/features 下没有裸 Colors.xxx', () {
    final hits = _scan(files, RegExp(r'(?<![A-Za-z])Colors\.[a-zA-Z]'));
    expect(
      hits,
      isEmpty,
      reason: '改用 AppColors.*（lib/shared/theme/colors.dart）:\n$hits',
    );
  });

  test('lib/features 下没有裸 Color(0x...) 字面量', () {
    // 写死 Colors.white / Color(0xFFFFFFFF) 的字在浅色主题下能看，
    // 切深色就变成「深底深字」。颜色只能从 ColorScheme 拿。
    final hits = _scan(files, RegExp(r'Color\(0x'));
    expect(
      hits,
      isEmpty,
      reason:
          '改用 Theme.of(context).colorScheme.* 或 lib/shared/theme/colors.dart 里的 token:\n$hits',
    );
  });

  test('itemBuilder 里不直接读主题（切浅色/深色会不换色）', () {
    // ListView/GridView 的 itemBuilder 是懒的：它的子项在新的 Theme 数据
    // 落地**之前**就重建完了，之后不再被通知，于是深色底配浅色主题的深色字。
    // 解法是返回值包一层 Builder，让它自己成为 Theme 的依赖。
    final hits = <String>[];
    for (final file in files) {
      final lines = _codeOf(file).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'itemBuilder:\s*\(').hasMatch(lines[i])) continue;
        // 只有懒列表的 itemBuilder 才有这个毛病；PopupMenuButton 那种子 builder
        // 每次弹窗都会重建，不在管辖范围内。
        final window = lines.sublist(i > 10 ? i - 10 : 0, i).join('\n');
        if (!RegExp(r'(ListView|GridView)\.builder\(').hasMatch(window)) {
          continue;
        }
        // 取出这个 itemBuilder 闭包的正文（靠大括号配平）。
        var depth = 0;
        var started = false;
        final body = <String>[];
        for (var j = i; j < lines.length && j < i + 60; j++) {
          for (final character in lines[j].split('')) {
            if (character == '{') {
              depth++;
              started = true;
            }
            if (character == '}') depth--;
          }
          body.add(lines[j]);
          if (started && depth <= 0) break;
        }
        // 已经包了 Builder 就是正解，不再检查里面。
        if (body.take(4).any((line) => line.contains('Builder('))) continue;
        for (var k = 0; k < body.length; k++) {
          if (body[k].contains('Theme.of(')) {
            hits.add('${file.path}:${i + k + 1} ${body[k].trim()}');
          }
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason: 'itemBuilder 的返回值包一层 Builder 再在里面读主题:\n$hits',
    );
  });

  test('lib/features 下没有裸 fontSize: 数字', () {
    final hits = _scan(files, RegExp(r'fontSize:\s*[0-9]'));
    expect(
      hits,
      isEmpty,
      reason: '改用 AppTypography.size() 或 AppTypography.sizeFixed():\n$hits',
    );
  });

  test('lib/features 下没有裸 BorderRadius.circular(数字)', () {
    final hits = _scan(files, RegExp(r'BorderRadius\.circular\(\s*[0-9]'));
    expect(hits, isEmpty, reason: '改用 AppRadius.*:\n$hits');
  });

  test('lib/features 下没有硬编码 EdgeInsets 数字', () {
    // EdgeInsets.all/symmetric/only/fromLTRB(...) 里不允许再出现裸数字。
    final hits = <String>[];
    for (final file in files) {
      final source = _codeOf(file);
      for (final match in RegExp(
        r'EdgeInsets\.(all|symmetric|only|fromLTRB)\(([^()]*)\)',
      ).allMatches(source)) {
        final args = match.group(2)!;
        // 0 是合法的「不要留白」，所以只查非零数字。
        if (RegExp(r'(?<![\w.])[1-9][0-9]*(?!\w)').hasMatch(args)) {
          final line = source.substring(0, match.start).split('\n').length;
          hits.add('${file.path}:$line ${match.group(0)}');
        }
      }
    }
    expect(hits, isEmpty, reason: '改用 AppSpacing.*:\n$hits');
  });

  test('lib/shared/widgets 与 components 也走同一套 token', () {
    final shared = _sharedFiles();
    expect(_scan(shared, RegExp(r'(?<![A-Za-z])Colors\.[a-zA-Z]')), isEmpty);
    expect(_scan(shared, RegExp(r'BorderRadius\.circular\(\s*[0-9]')), isEmpty);
    expect(_scan(shared, RegExp(r'fontSize:\s*[0-9]')), isEmpty);
    expect(_scan(shared, RegExp(r'Color\(0x')), isEmpty);
  });
}

/// lib/features 下的全部 .dart。
List<File> _featureFiles() => _dartFiles(Directory('lib/features'));

/// lib/shared/widgets + lib/shared/components（theme 层是 token 的定义处，放行）。
List<File> _sharedFiles() => [
  ..._dartFiles(Directory('lib/shared/widgets')),
  ..._dartFiles(Directory('lib/shared/components')),
];

List<File> _dartFiles(Directory directory) => directory
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (file) => file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'),
    )
    .toList(growable: false);

/// 去掉注释与行尾噪音，只留真代码。
String _codeOf(File file) => file
    .readAsLinesSync()
    .map((line) => line.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

/// 扫出所有命中行，拼成可读的报告。
String _scan(List<File> files, RegExp pattern) => files
    .map((file) {
      final lines = _codeOf(file).split('\n');
      final hits = <String>[];
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('${file.path}:${i + 1} ${lines[i].trim()}');
        }
      }
      return hits;
    })
    .expand((hits) => hits)
    .join('\n');
