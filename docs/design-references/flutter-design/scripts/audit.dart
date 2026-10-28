// Deterministic Flutter UI audit: slop, theming and accessibility tells.
//
// Usage:
//   dart run scripts/audit.dart lib/            # human report
//   dart run scripts/audit.dart lib/ --json     # machine report
//
// Output line: path:line  RULE-ID  Pn  message
// Exit code 1 if any P0 or P1 finding. Add `// audit:ignore` on a line to skip it.
// Findings are heuristics: confirm in a render. Rule files: reference/rules/<RULE-ID>.md
import 'dart:convert';
import 'dart:io';

class Finding {
  Finding(this.file, this.line, this.rule, this.severity, this.message);
  final String file;
  final int line;
  final String rule;
  final String severity;
  final String message;
  Map<String, Object> toJson() =>
      {'file': file, 'line': line, 'rule': rule, 'severity': severity, 'message': message};
}

class LineRule {
  LineRule(this.rule, this.severity, this.pattern, this.message, {this.skipThemeFiles = false});
  final String rule;
  final String severity;
  final RegExp pattern;
  final String message;
  final bool skipThemeFiles;
}

final _themeFile = RegExp(r'(theme|tokens|palette|colors|color_scheme|app_colors|design_system)', caseSensitive: false);

final _lineRules = <LineRule>[
  LineRule('theme-default-seed', 'P1', RegExp(r'Colors\.deepPurple|0xFF6750A4|0xff6750a4'),
      'Default Flutter template seed color. Choose a seed from the brief.'),
  LineRule('theme-raw-colors', 'P1', RegExp(r'\bColors\.(?!transparent\b)[a-zA-Z]+|\bColor\(\s*0x[0-9a-fA-F]{8}\s*\)'),
      'Raw color in widget code. Use colorScheme roles or a ThemeExtension.',
      skipThemeFiles: true),
  LineRule('theme-inline-textstyle', 'P1', RegExp(r'TextStyle\([^)]*\b(fontSize|fontFamily)\s*:'),
      'Inline fontSize/fontFamily. Use a textTheme role.',
      skipThemeFiles: true),
  LineRule('theme-brightness-branch', 'P1',
      RegExp(r'(brightness|platformBrightness)\s*==\s*Brightness\.(dark|light)|isDark(Mode)?\s*\?'),
      'Branching on brightness in a widget. Read colorScheme roles instead.',
      skipThemeFiles: true),
  LineRule('type-body-size', 'P1', RegExp(r'fontSize\s*:\s*(?:[0-9]|1[01])(?:\.\d+)?\s*[,)]'),
      'Font size below 12sp.'),
  LineRule('type-text-scaler', 'P0', RegExp(r'TextScaler\.noScaling|textScaleFactor\s*:\s*1(?:\.0)?\b'),
      'Text scaling disabled. Allow user scaling (clamp narrowly if needed).'),
  LineRule('layout-no-device-type', 'P1', RegExp(r'\bPlatform\.is(IOS|Android|MacOS|Windows|Linux)\b'),
      'Platform.isX in UI code (breaks web/tests). Use Theme.of(context).platform or window size classes.'),
  LineRule('layout-sizeof-over-of', 'P2', RegExp(r'MediaQuery\.of\('),
      'MediaQuery.of rebuilds on any change. Use sizeOf/paddingOf/viewInsetsOf.'),
  LineRule('platform-predictive-back', 'P2', RegExp(r'\bWillPopScope\b'),
      'WillPopScope is deprecated. Use PopScope (predictive back).'),
  LineRule('motion-no-ease-in', 'P2', RegExp(r'Curves\.easeIn(?:Quad|Cubic|Quart|Quint|Expo|Sine|Circ|Back)?\b'),
      'Ease-in on UI motion feels laggy. Use ease-out curves.'),
  LineRule('copy-no-lorem', 'P1', RegExp(r'lorem ipsum|\bJohn Doe\b|\bJane Doe\b|\bAcme\b', caseSensitive: false),
      'Placeholder content.'),
  LineRule('copy-specific-labels', 'P2', RegExp(r"""Text\(\s*['"](OK|Submit|Continue|Yes|Click here)['"]"""),
      'Vague button label. Name the action.'),
  LineRule('icon-no-emoji', 'P2',
      RegExp('Text\\(\\s*[\'"][^\'"]*[\\u{1F300}-\\u{1FAFF}\\u{2600}-\\u{27BF}]', unicode: true),
      'Emoji in UI text (as icon?). Use vector icons.'),
  LineRule('color-no-gradient-slop', 'P2', RegExp(r'LinearGradient\([^)]*(purple|deepPurple|indigo|blueAccent)', caseSensitive: false),
      'Purple/blue gradient is the default AI look.'),
  LineRule('type-no-allcaps-eyebrow', 'P3', RegExp(r'letterSpacing\s*:\s*(?:[2-9]|1\.[5-9])\b.*(?:toUpperCase|fontSize\s*:\s*1[0-2])|toUpperCase\(\).*letterSpacing\s*:\s*(?:[2-9]|1\.[5-9])'),
      'Tracked ALL CAPS label (eyebrow chrome).'),
];

/// Find balanced `Name(...)` calls; returns (startLine, text).
Iterable<(int, String)> calls(String src, String name) sync* {
  final re = RegExp('\\b$name\\(');
  for (final m in re.allMatches(src)) {
    var depth = 0;
    var i = m.end - 1;
    for (; i < src.length; i++) {
      final c = src[i];
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
    yield (line, src.substring(m.start, i.clamp(0, src.length - 1) + 1));
  }
}

List<Finding> auditFile(File f, String display) {
  final src = f.readAsStringSync();
  final lines = src.split('\n');
  final out = <Finding>[];
  final isThemeFile = _themeFile.hasMatch(display);
  bool ignored(int line) => line - 1 < lines.length && lines[line - 1].contains('audit:ignore');

  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final trimmed = l.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///') || l.contains('audit:ignore')) continue;
    for (final r in _lineRules) {
      if (r.skipThemeFiles && isThemeFile) continue;
      if (r.pattern.hasMatch(l)) out.add(Finding(display, i + 1, r.rule, r.severity, r.message));
    }
  }

  for (final (line, text) in calls(src, 'IconButton')) {
    if (ignored(line)) continue;
    if (!text.contains('tooltip:') && !text.contains('Semantics')) {
      out.add(Finding(display, line, 'a11y-semantics-label', 'P0', 'IconButton without tooltip or Semantics label.'));
    }
  }
  for (final (line, text) in calls(src, 'GestureDetector')) {
    if (ignored(line)) continue;
    final tappable = text.contains('onTap');
    if (tappable && (text.contains('Icon(') || text.contains('Image.')) && !text.contains('Semantics') && !text.contains('semanticLabel')) {
      out.add(Finding(display, line, 'a11y-tap-target', 'P0',
          'GestureDetector on icon/image: no 48dp target or Semantics. Use IconButton/InkWell with constraints.'));
    }
  }
  for (final (line, text) in calls(src, 'ListView')) {
    if (ignored(line)) continue;
    if (text.contains('children:') && text.contains('.map(')) {
      out.add(Finding(display, line, 'perf-listview-builder', 'P1', 'ListView(children: x.map) builds all items. Use ListView.builder.'));
    }
  }
  for (final (line, text) in calls(src, 'TextStyle')) {
    if (ignored(line) || isThemeFile) continue;
    final opener = lines[line - 1];
    if (opener.contains('fontSize:') || opener.contains('fontFamily:')) continue; // already reported per line
    if (RegExp(r'\b(fontSize|fontFamily)\s*:').hasMatch(text)) {
      out.add(Finding(display, line, 'theme-inline-textstyle', 'P1', 'Inline fontSize/fontFamily across lines. Use a textTheme role.'));
    }
  }
  final grid = RegExp(
    r'(?:SizedBox\(\s*(?:height|width)\s*:\s*'
    r'|EdgeInsets\.all\(\s*'
    r'|EdgeInsets\.symmetric\(\s*(?:horizontal|vertical)\s*:\s*'
    r'|EdgeInsets\.only\(\s*(?:left|right|top|bottom)\s*:\s*'
    r')(\d+(?:\.\d+)?)',
  );
  for (final m in grid.allMatches(src)) {
    final n = double.tryParse(m.group(1)!);
    if (n == null || n == 0 || n % 4 == 0) continue;
    final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
    if (ignored(line) || isThemeFile) continue;
    out.add(Finding(display, line, 'layout-grid-4-8', 'P3', 'Literal ${m.group(1)} is off the 4dp grid.'));
  }

  for (final (line, text) in calls(src, 'MaterialApp')) {
    if (ignored(line)) continue;
    if (text.contains('theme:') && !text.contains('darkTheme:')) {
      out.add(Finding(display, line, 'theme-light-dark-pair', 'P1', 'MaterialApp has theme but no darkTheme.'));
    }
  }

  // File-level heuristics
  final acCount = 'AnimatedContainer('.allMatches(src).length;
  if (acCount >= 5) {
    out.add(Finding(display, 1, 'motion-one-moment', 'P2', '$acCount AnimatedContainer uses in one file. Motion as decoration?'));
  }
  final pad16 = 'EdgeInsets.all(16)'.allMatches(src).length;
  if (pad16 >= 6) {
    out.add(Finding(display, 1, 'layout-rhythm', 'P2', 'EdgeInsets.all(16) used $pad16 times. Vary spacing to express grouping.'));
  }
  final radii = <String, int>{};
  for (final m in RegExp(r'BorderRadius\.circular\((\d+(?:\.\d+)?)\)').allMatches(src)) {
    radii.update(m.group(1)!, (v) => v + 1, ifAbsent: () => 1);
  }
  for (final e in radii.entries) {
    if (e.value >= 6 && !isThemeFile) {
      out.add(Finding(display, 1, 'theme-radius-tokens', 'P2', 'Radius ${e.key} repeated ${e.value}x. Use a radius token scale.'));
    }
  }
  if (src.contains('CupertinoIcons.') && RegExp(r'\bIcons\.').hasMatch(src)) {
    out.add(Finding(display, 1, 'icon-one-family', 'P2', 'Material Icons and CupertinoIcons mixed in one file.'));
  }
  return out;
}

String dimensionOf(String rule) {
  if (rule.startsWith('a11y-') || rule == 'type-text-scaler' || rule == 'type-body-size') return 'Accessibility';
  if (rule.startsWith('theme-') || rule.startsWith('color-')) return 'Theming';
  if (rule.startsWith('layout-') || rule.startsWith('platform-')) return 'Responsive';
  if (rule.startsWith('perf-')) return 'Performance';
  return 'Integrity';
}

int scoreFor(Iterable<Finding> fs) {
  if (fs.any((f) => f.severity == 'P0')) return 0;
  if (fs.any((f) => f.severity == 'P1')) return 1;
  if (fs.any((f) => f.severity == 'P2')) return 2;
  if (fs.any((f) => f.severity == 'P3')) return 3;
  return 4;
}

String band(int s) => s >= 18 ? 'Excellent' : s >= 14 ? 'Good' : s >= 10 ? 'Acceptable' : s >= 6 ? 'Poor' : 'Critical';

void main(List<String> args) {
  final json = args.contains('--json');
  final paths = args.where((a) => !a.startsWith('--')).toList();
  if (paths.isEmpty) {
    stderr.writeln('Usage: dart run scripts/audit.dart <path...> [--json]');
    exit(64);
  }
  final findings = <Finding>[];
  var files = 0;
  for (final p in paths) {
    final type = FileSystemEntity.typeSync(p);
    final entities = type == FileSystemEntityType.directory
        ? Directory(p).listSync(recursive: true).whereType<File>()
        : type == FileSystemEntityType.file
            ? [File(p)]
            : <File>[];
    for (final f in entities) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) continue;
      if (f.path.contains('/test/') || f.path.contains('/generated/')) continue;
      files++;
      findings.addAll(auditFile(f, f.path));
    }
  }
  findings.sort((a, b) {
    final s = a.severity.compareTo(b.severity);
    return s != 0 ? s : a.file != b.file ? a.file.compareTo(b.file) : a.line.compareTo(b.line);
  });

  const dims = ['Accessibility', 'Theming', 'Responsive', 'Performance', 'Integrity'];
  final scores = {for (final d in dims) d: scoreFor(findings.where((f) => dimensionOf(f.rule) == d))};
  final total = scores.values.fold<int>(0, (a, b) => a + b);

  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'files': files,
      'score': total,
      'band': band(total),
      'dimensions': scores,
      'findings': findings.map((f) => f.toJson()).toList(),
    }));
  } else {
    stdout.writeln('Audit score (automated checks only): $total/20 (${band(total)})  files: $files');
    stdout.writeln(dims.map((d) => '$d ${scores[d]}').join(' | '));
    stdout.writeln('');
    for (final f in findings) {
      stdout.writeln('${f.file}:${f.line}  ${f.rule}  ${f.severity}  ${f.message}');
    }
    if (findings.isEmpty) stdout.writeln('No automated findings. Still render and check contrast, hierarchy and states.');
    stdout.writeln('');
    stdout.writeln(findings.isEmpty
        ? 'Next: render goldens/screenshots and run critique.'
        : 'Next: fix P0/P1 (see reference/rules/<RULE-ID>.md), run polish, re-run audit to see the score improve.');
  }
  exit(findings.any((f) => f.severity == 'P0' || f.severity == 'P1') ? 1 : 0);
}
