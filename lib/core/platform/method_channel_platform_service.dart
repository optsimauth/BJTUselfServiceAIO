import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'platform_service.dart';

/// 默认实现：能纯 Dart 做的就纯 Dart 做，做不了的走平台通道。
/// 每个平台子类只覆写真正有差异的方法。
abstract class MethodChannelPlatformService implements PlatformService {
  MethodChannelPlatformService({String? channelName})
    : channel = MethodChannel(channelName ?? 'bjtuselfservice/platform');

  @protected
  final MethodChannel channel;

  /// 调平台通道，并把「这个平台压根没实现这个方法」降级成 null。
  ///
  /// Windows runner 没有注册任何 MethodChannelHandler，所以 openFile / notify /
  /// pickFiles 全是 MissingPluginException —— 那是**编程错误被当成运行时错误**抛出去，
  /// 顺带变成一条未捕获的异步异常（日志里能刷出好几屏）。没实现就是没实现，
  /// 交回 null 让调用方走降级分支，比抛异常正确。
  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<Directory> appDataDirectory() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<Directory> tempDirectory() => getTemporaryDirectory();

  @override
  Future<List<String>> pickFiles({List<String> extensions = const []}) async {
    final result = await _invoke<List<dynamic>>('pickFiles', {
      'extensions': extensions,
    });
    return result?.cast<String>() ?? const <String>[];
  }

  @override
  Future<String?> saveToDownloads({
    required String fileName,
    required List<int> bytes,
    String? directory,
    String? mimeType,
  }) async {
    var target = directory == null || directory.isEmpty
        ? await downloadsDirectory()
        : Directory(directory);
    // 用户选的目录可能已经被删了或者没权限，创建失败就退回默认目录。
    try {
      await target.create(recursive: true);
    } catch (_) {
      target = await downloadsDirectory();
    }
    // 用 p.join 拼：Windows 上手写 '/' 会留下混合分隔符（\\dir/file.pdf）。
    final file = File(p.join(target.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<bool> openFile(String path) async {
    final opened = await _invoke<bool>('openFile', {'path': path});
    if (opened == true) return true;
    // 桌面端没人实现这个通道：用系统的默认程序打开就行（explorer / open）。
    if (Platform.isWindows) {
      return _spawn('explorer', [path]);
    }
    if (Platform.isMacOS) {
      return _spawn('open', [path]);
    }
    return false;
  }

  @override
  Future<bool> openUrl(String url) async {
    final opened = await _invoke<bool>('openUrl', {'url': url});
    if (opened == true) return true;
    if (Platform.isWindows) {
      return _spawn('cmd', ['/c', 'start', '', url]);
    }
    if (Platform.isMacOS) {
      return _spawn('open', [url]);
    }
    return false;
  }

  @override
  Future<void> notify({required String title, required String body}) async =>
      _invoke<void>('notify', {'title': title, 'body': body});

  @override
  Future<void> refreshHomeWidget(Map<String, Object?> payload) async =>
      _invoke<void>('refreshHomeWidget', payload);

  /// 起一个外部进程。系统壳子起不来是环境问题，不该把调用方一起带崩。
  static Future<bool> _spawn(String executable, List<String> arguments) async {
    try {
      await Process.start(executable, arguments);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, String>> defaultRequestHeaders() async => const {};

  /// 系统下载目录。桌面端没有系统 API，落回「文档/Downloads」。
  ///
  /// 暴露出来是因为上层要往里拼子目录（见 DownloadService）：设置里没选
  /// 目录时，也得知道往哪拼 app 那一层文件夹。
  @override
  Future<Directory> downloadsDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/Downloads');
    await directory.create(recursive: true);
    return directory;
  }
}
