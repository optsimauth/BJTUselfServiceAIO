// Search flutter-design data and generate a Dart design-system starter.
//
// Usage:
//   dart run scripts/search.dart "calm meditation app"
//   dart run scripts/search.dart "fintech bold" --domain palette -n 3
//   dart run scripts/search.dart "habit tracker mobile" --design-system
//
// Domains: palette, font, style, motion. No dependencies beyond the Dart SDK.
import 'dart:io';
import 'dart:math' as math;

class Row {
  Row(this.domain, this.fields);
  final String domain;
  final Map<String, String> fields;
  String get text => fields.values.join(' ').toLowerCase();
  String get keywords => (fields['keywords'] ?? '').replaceAll(';', ' ').toLowerCase();
}

const _files = {
  'palette': 'palettes.csv',
  'font': 'fonts.csv',
  'style': 'styles.csv',
  'motion': 'motion.csv',
};

String get _root {
  final script = File.fromUri(Platform.script).absolute;
  return script.parent.parent.path;
}

List<Row> load(String domain) {
  final file = File('$_root/data/${_files[domain]}');
  final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
  final header = lines.first.split(',');
  return [
    for (final line in lines.skip(1))
      Row(domain, {
        for (final e in line.split(',').asMap().entries)
          if (e.key < header.length) header[e.key]: e.value.trim(),
      }),
  ];
}

List<String> tokenize(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.length > 1 && !_stop.contains(t))
    .toList();

const _stop = {'app', 'the', 'and', 'for', 'with', 'mobile', 'ui', 'ux', 'screen', 'flutter'};

/// BM25-style scoring; keyword field weighted x3.
List<MapEntry<Row, double>> rank(List<Row> rows, String query, {int n = 3}) {
  final q = tokenize(query);
  if (q.isEmpty) return [];
  final docs = rows.map((r) => tokenize('${r.keywords} ${r.keywords} ${r.keywords} ${r.text}')).toList();
  final avg = docs.fold<int>(0, (a, d) => a + d.length) / docs.length;
  const k1 = 1.5, b = 0.75;
  final scores = <MapEntry<Row, double>>[];
  for (var i = 0; i < rows.length; i++) {
    var score = 0.0;
    for (final term in q.toSet()) {
      final df = docs.where((d) => d.contains(term)).length;
      if (df == 0) continue;
      final idf = math.log(1 + (docs.length - df + 0.5) / (df + 0.5));
      final tf = docs[i].where((t) => t == term).length;
      score += idf * (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * docs[i].length / avg));
    }
    if (score > 0) scores.add(MapEntry(rows[i], score));
  }
  scores.sort((a, b) => b.value.compareTo(a.value));
  return scores.take(n).toList();
}

String designSystem(String query) {
  final pal = rank(load('palette'), query, n: 1);
  final font = rank(load('font'), query, n: 1);
  final style = rank(load('style'), query, n: 1);
  final motion = load('motion');
  if (pal.isEmpty) {
    return 'No palette matched "$query". Try 2-5 domain words (e.g. "fitness habit calm") '
        'and do not invent results; choose from data/palettes.csv by hand.';
  }
  final p = pal.first.key.fields;
  final f = font.isEmpty ? load('font').first.fields : font.first.key.fields;
  final s = style.isEmpty ? load('style').first.fields : style.first.key.fields;
  final byId = {for (final m in motion) m.fields['id']!: m.fields};
  final b = StringBuffer()
    ..writeln('// Design system for: $query')
    ..writeln('// Palette ${p['id']} "${p['name']}", font ${f['id']} "${f['name']}", style ${s['id']} "${s['name']}"')
    ..writeln('// Dials suggestion: VARIANCE ${s['variance']}  MOTION ${s['motion']}  DENSITY ${s['density']}')
    ..writeln('// Style: ${s['description']}. Avoid: ${s['avoid']}.')
    ..writeln('// Palette note: ${p['notes']}')
    ..writeln()
    ..writeln('const seed = Color(${p['seed']});')
    ..writeln('const secondarySeed = Color(${p['secondary']}); // use in a ThemeExtension or override secondary')
    ..writeln('const tertiarySeed = Color(${p['tertiary']});')
    ..writeln('const neutralTint = Color(${p['neutral']}); // light surface tint; derive dark via fromSeed')
    ..writeln()
    ..writeln('final light = ColorScheme.fromSeed(')
    ..writeln('  seedColor: seed,')
    ..writeln('  dynamicSchemeVariant: DynamicSchemeVariant.${p['variant']},')
    ..writeln(');')
    ..writeln('final dark = ColorScheme.fromSeed(')
    ..writeln('  seedColor: seed,')
    ..writeln('  brightness: Brightness.dark,')
    ..writeln('  dynamicSchemeVariant: DynamicSchemeVariant.${p['variant']},')
    ..writeln(');')
    ..writeln('// secondarySeed and tertiarySeed are NOT copied onto the scheme.')
    ..writeln('// A raw hex plus the generated onSecondary/onTertiary fails 4.5:1 on most of these palettes.')
    ..writeln('// Use them as ThemeExtension accents, or fromSeed(seedColor: secondarySeed) and read that scheme\'s onSecondary.')
    ..writeln()
    ..writeln('// Typography: display = ${f['display']}, text = ${f['text']}, mono = ${f['mono']} (${f['scripts']})')
    ..writeln('// ${f['notes']}')
    ..writeln('TextTheme buildTextTheme(TextTheme base) {')
    ..writeln('  final text = ${_gf(f['text']!)}(base);')
    ..writeln('  return text.copyWith(')
    ..writeln('    displayLarge: ${_gfStyle(f['display']!)}(textStyle: base.displayLarge),')
    ..writeln('    displayMedium: ${_gfStyle(f['display']!)}(textStyle: base.displayMedium),')
    ..writeln('    displaySmall: ${_gfStyle(f['display']!)}(textStyle: base.displaySmall),')
    ..writeln('    headlineLarge: ${_gfStyle(f['display']!)}(textStyle: base.headlineLarge),')
    ..writeln('  );')
    ..writeln('}')
    ..writeln('// Bundle fonts for release (type-font-bundling).')
    ..writeln()
    ..writeln('abstract final class Motion {');
  for (final id in ['m01', 'm02', 'm06', 'm08']) {
    final m = byId[id];
    if (m == null) continue;
    b.writeln('  // ${m['name']}: ${m['use']} (${m['notes']})');
    b.writeln('  static const ${_camel(m['name']!)} = Duration(milliseconds: ${m['duration_ms']});');
  }
  b
    ..writeln('  static const enter = Cubic(0.23, 1, 0.32, 1);')
    ..writeln('  static const exitCurve = Cubic(0.3, 0, 0.8, 0.15);')
    ..writeln('}')
    ..writeln()
    ..writeln('// Spacing: 4 8 12 16 24 32 48. Radius rule: ${s['shape']}.')
    ..writeln('// Next: write DESIGN.md, then build with tokens only.');
  return b.toString();
}

String _camel(String s) {
  final parts = s.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty).toList();
  return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String _gf(String family) =>
    family == 'system-ui' ? '(TextTheme t) => t.apply' : 'GoogleFonts.${_camel(family)}TextTheme';

String _gfStyle(String family) =>
    family == 'system-ui' ? 'TextStyle.new' : 'GoogleFonts.${_camel(family)}';

void main(List<String> args) {
  String? domain;
  var n = 3;
  var ds = false;
  final q = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--domain' && i + 1 < args.length) {
      domain = args[++i];
    } else if (a == '-n' && i + 1 < args.length) {
      n = int.tryParse(args[++i]) ?? 3;
    } else if (a == '--design-system') {
      ds = true;
    } else if (a == '-h' || a == '--help') {
      stdout.writeln('dart run scripts/search.dart "<query>" [--domain palette|font|style|motion] [-n 3] [--design-system]');
      return;
    } else {
      q.add(a);
    }
  }
  final query = q.join(' ');
  if (query.isEmpty) {
    stderr.writeln('Provide a query: 2-5 domain words, one intent.');
    exit(64);
  }
  if (ds) {
    stdout.writeln(designSystem(query));
    return;
  }
  final domains = domain == null ? _files.keys.toList() : [domain];
  var any = false;
  for (final d in domains) {
    if (!_files.containsKey(d)) {
      stderr.writeln('Unknown domain "$d". Use: ${_files.keys.join(', ')}');
      exit(64);
    }
    final res = rank(load(d), query, n: n);
    if (res.isEmpty) continue;
    any = true;
    stdout.writeln('## $d');
    for (final e in res) {
      final f = e.key.fields;
      stdout.writeln('- ${f['id']} ${f['name']} (score ${e.value.toStringAsFixed(2)})');
      for (final k in f.keys.where((k) => k != 'id' && k != 'name' && k != 'keywords')) {
        stdout.writeln('    $k: ${f[k]}');
      }
    }
  }
  if (!any) {
    stdout.writeln('No results for "$query". Retry once with different domain words; do not fabricate results.');
  }
}
