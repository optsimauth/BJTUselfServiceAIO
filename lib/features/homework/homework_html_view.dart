import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:webview_all/webview_all.dart';

import '../../shared/theme/spacing.dart';

/// 正文是平台给的 **HTML**。旧项目（Kotlin）就是这么显示的：
/// `HomeworkDetailDialog` 里一个 WebView + `loadDataWithBaseURL(buildHomeworkHtml(...))`。
/// 这里照做，只把排版细节换成 App 的规范。
///
/// 三条底线：
/// 1. **颜色跟着主题走**：WebView 默认白底黑字，深色模式下会在大半屏的
///    `surfaceContainerHigh` 上闪一块白。底色和字色都写进 CSS。
/// 2. **字号跟着系统字号走**：旧项目是 `textZoom = 120 * fontScale`，
///    这里换算成 CSS 的 `font-size`（视口按 `width=device-width` 设好，
///    CSS px 就等于逻辑像素）。
/// 3. **没有 WebView 就退回纯文本**：老 Win10 没装 WebView2、flutter_tester
///    里没有平台视图，此时与其白屏，不如把标签剥掉照常能读。
class HomeworkHtmlView extends StatefulWidget {
  const HomeworkHtmlView({super.key, required this.html});

  /// 平台原文。可能是 `<p>…</p>` 这样的标记，也可能是带换行的纯文本。
  final String html;

  @override
  State<HomeworkHtmlView> createState() => _HomeworkHtmlViewState();
}

class _HomeworkHtmlViewState extends State<HomeworkHtmlView> {
  WebViewController? _controller;

  /// 平台没有 WebView 实现，或建控制器就失败（Windows 缺 WebView2）。
  bool _unsupported = false;

  bool _loading = true;

  /// 主文档加载失败的原因。非 null 时同样退回纯文本。
  String? _error;

  /// 上一次渲染的文档，避免主题没变时反复 load。
  String? _rendered;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null && !_unsupported) _createController();
    // 主题 / 系统字号变了要重新灌一份 CSS 进去。
    if (!_unsupported && _error == null) _render();
  }

  @override
  void didUpdateWidget(covariant HomeworkHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) _render();
  }

  void _createController() {
    // 测试环境里没有任何平台实现，`WebViewPlatform.instance` 就是 null。
    if (WebViewPlatform.instance == null) {
      _unsupported = true;
      return;
    }
    try {
      final background = _surfaceOf(context);
      _controller = WebViewController()
        ..setBackgroundColor(background)
        // 作业正文里不该有脚本，关掉少一个攻击面。
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted && _loading) setState(() => _loading = false);
            },
            onWebResourceError: (error) {
              // 只认主文档的失败：正文里的图挂了不该把整篇换成纯文本。
              if (error.isForMainFrame ?? true) {
                if (!mounted) return;
                setState(() {
                  _loading = false;
                  _error = error.description;
                });
              }
            },
          ),
        );
    } on Object {
      // 典型场景：Windows 上没装 WebView2 运行时，控制器起不来。
      _controller = null;
      _unsupported = true;
    }
  }

  void _render() {
    final controller = _controller;
    if (controller == null) return;
    final theme = Theme.of(context);
    final document = buildHomeworkHtml(
      widget.html,
      scheme: theme.colorScheme,
      background: _surfaceOf(context),
      fontSize: MediaQuery.textScalerOf(context).scale(_baseFontSize),
    );
    if (document == _rendered) return;
    _rendered = document;
    unawaited(
      controller.loadHtmlString(document).catchError((Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }),
    );
  }

  /// 弹窗底色：和 `dialogTheme` 一致，才不会在圆角外露出另一种灰。
  Color _surfaceOf(BuildContext context) {
    final theme = Theme.of(context);
    return theme.dialogTheme.backgroundColor ??
        theme.colorScheme.surfaceContainerHigh;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_unsupported || _error != null || controller == null) {
      return _PlainTextView(html: widget.html, reason: _error);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: controller),
        // 平台视图是同步出现的，但首帧到文档就绪之间是空白：给一个转圈，
        // 免得用户以为「作业内容」这栏没有东西。
        if (_loading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/// 没有 WebView 时的降级：把标签剥掉，按段落换行。
class _PlainTextView extends StatelessWidget {
  const _PlainTextView({required this.html, this.reason});

  final String html;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = htmlToPlainText(html);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text.isEmpty ? homeworkEmptyContentHint : text,
            style: theme.textTheme.bodyMedium,
          ),
          if (reason != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '网页视图不可用，已按纯文本显示',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 平台没写要求时的占位文案。旧项目也是这句。
const String homeworkEmptyContentHint = '老师没有写具体要求';

/// 和系统字号同基线：旧项目正文 16px、`textZoom` 再乘 1.2。
const double _baseFontSize = 16;

/// 弹窗里正文的排版。等价于旧项目的 `buildHomeworkHtml`，
/// 多做了「主题色 + 系统字号」两件事。
String buildHomeworkHtml(
  String content, {
  required ColorScheme scheme,
  required Color background,
  required double fontSize,
}) {
  final trimmed = content.trim();
  final body = trimmed.isEmpty
      ? '<p class="plain">$homeworkEmptyContentHint</p>'
      : _looksLikeMarkup(trimmed)
      ? trimmed
      : '<p class="plain">${const HtmlEscape().convert(trimmed)}</p>';
  final text = _cssColor(scheme.onSurface);
  final accent = _cssColor(scheme.primary);
  final line = _cssColor(scheme.outlineVariant);
  final code = _cssColor(scheme.surfaceContainerHighest);
  final muted = _cssColor(scheme.onSurfaceVariant);
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; }
  body {
    background: ${_cssColor(background)};
    color: $text;
    font-size: ${fontSize.toStringAsFixed(1)}px;
    line-height: 1.75;
    overflow-wrap: anywhere;
    word-break: break-word;
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans SC", sans-serif;
    padding: 0 0 12px;
  }
  p { margin: 0 0 0.9em; }
  /* 平台正文常是带换行的纯文本，靠它保住段落。 */
  .plain { white-space: pre-wrap; }
  a { color: $accent; }
  img, video { max-width: 100%; height: auto; }
  table { max-width: 100%; display: block; overflow-x: auto; border-collapse: collapse; }
  th, td { border: 1px solid $line; padding: 4px 8px; }
  pre, code { background: $code; border-radius: 6px; padding: 2px 4px; white-space: pre-wrap; }
  blockquote { margin: 0 0 0.9em; padding-left: 12px; border-left: 3px solid $line; color: $muted; }
</style>
</head>
<body>$body</body>
</html>
''';
}

/// 纯文本降级用：剥标签，但保住段落换行。
String htmlToPlainText(String html) {
  final trimmed = html.trim();
  if (trimmed.isEmpty) return '';
  if (!_looksLikeMarkup(trimmed)) return trimmed;
  final withBreaks = trimmed
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|li|tr|h[1-6])\s*>', caseSensitive: false),
        '\n',
      );
  final text = html_parser.parseFragment(withBreaks).text ?? '';
  return text
      .replaceAll('\u00a0', ' ')
      .split('\n')
      .map((line) => line.trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// 有没有 HTML 标记。没有就整段按纯文本转义 —— 平台有些作业正文就是
/// 带换行的普通文字，直接塞进 `<body>` 会把换行丢掉。
bool _looksLikeMarkup(String value) =>
    RegExp(r'</?[a-zA-Z][^>]*>').hasMatch(value);

String _cssColor(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
