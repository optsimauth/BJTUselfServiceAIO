import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';

import '../../app/service_locator.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import 'web_navigation.dart';

/// 直接在 app 里看学校网页版。功能还没做的那部分先这么顶着用。
///
/// 免登录靠的是把 AppCookieManager 里的 cookie 注入 WebView：
/// 账号信息 App 和网页是同一份，登录一次后两边都算登录态。
///
/// 后端用 [webview_all]：安卓 / iOS / macOS / Windows / Linux 一套 API，
/// Windows 走系统 WebView2，所以这份代码不用分平台。
/// 万一运行时缺失（老 Win10 没装 WebView2），[_load] 会兜住，
/// 露出「加载失败 + 在浏览器中打开」。
class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.url, this.title = '网页版'});

  final String url;
  final String title;

  @override
  State<WebPage> createState() => _WebPageState();
}

class _WebPageState extends State<WebPage> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) => setState(() => _progress = value),
          // 这三行日志是排查 Windows 跳转问题的：跑一次就能分清
          // 是「点击根本没进来」（连 START 都没有）还是「进来了但渲染不出来」。
          onPageStarted: (url) {
            debugPrint('web: START $url');
            if (mounted) setState(() => _error = null);
          },
          onPageFinished: (url) => debugPrint('web: DONE  $url'),
          onWebResourceError: (error) {
            debugPrint(
              'web: ERR   ${error.url ?? '?'} code=${error.errorCode} '
              'frame=${error.isForMainFrame} ${error.description}',
            );
            if (error.isForMainFrame ?? true) {
              if (mounted) setState(() => _error = error.description);
            }
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            // 相对地址（scheme 为空）也是教务系统的正常菜单入口，
            // 早先这里只放行 http/https，结果点任何菜单都被静默拦掉。
            if (uri == null || isWebviewNavigation(uri)) {
              return NavigationDecision.navigate;
            }
            // 外部协议交给系统；系统没装对应 App 就仍留在 WebView 里，
            // 免得用户被卡在原地。
            final handedOff = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!handedOff) return NavigationDecision.navigate;
            // 只在真的拦下来时打一行日志：万一还有跳不动的地方，
            // 这行能直接告诉你是哪个 URL 被挡了。
            debugPrint('web: 交给系统打开 $uri');
            return NavigationDecision.prevent;
          },
        ),
      );
    _load();
  }

  Future<void> _load() async {
    final uri = Uri.parse(widget.url);
    try {
      await _injectCookies(uri);
      await _controller.loadRequest(uri);
    } catch (error) {
      // 典型场景：Windows 上没装 WebView2 运行时，控制器起不来。
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  /// 把 App 的登录 cookie 写进 WebView 自己的 cookie 库。
  Future<void> _injectCookies(Uri uri) async {
    final header = await ServiceScope.of(context).cookieManager
        .cookieHeaderFor(uri);
    for (final pair in header.split(';')) {
      final name = pair.split('=').first.trim();
      final value = pair.substring(pair.indexOf('=') + 1).trim();
      if (name.isEmpty || value.isEmpty) continue;
      await WebViewCookieManager().setCookie(
        WebViewCookie(name: name, value: value, domain: uri.host, path: '/'),
      );
    }
  }

  Future<void> _openExternally() async {
    final current = await _controller.currentUrl();
    await launchUrl(
      Uri.parse(current ?? widget.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _controller.reload,
          ),
          IconButton(
            tooltip: '在浏览器中打开',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternally,
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('加载失败：$_error', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _load, child: const Text('重试')),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _openExternally,
                    child: const Text('在浏览器中打开'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
