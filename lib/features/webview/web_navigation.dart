/// 这个跳转要不要留在 WebView 里。
///
/// 教务网页里的菜单入口大量是相对地址（`/module/module/28/`），
/// scheme 为空 —— 那也是网页内跳转，必须放行。
/// 只有 tel: / mailto: / weixin: 这类外部协议才交给系统，WebView 打不开它们。
bool isWebviewNavigation(Uri uri) =>
    uri.scheme.isEmpty || uri.scheme == 'http' || uri.scheme == 'https';
