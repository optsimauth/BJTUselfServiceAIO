import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../method_channel_platform_service.dart';
import '../platform_service.dart';

class AndroidPlatformService extends MethodChannelPlatformService {
  AndroidPlatformService() : super(channelName: 'bjtuselfservice/android');

  @override
  PlatformKind get kind => PlatformKind.android;

  @override
  Future<String?> saveToDownloads({
    required String fileName,
    required List<int> bytes,
    String? directory,
    String? mimeType,
  }) async {
    // 指定了目录就纯 Dart 写：原生 saveToDownloads 只会落 MediaStore 的
    // Download 目录，装不下「高等数学/第1章/1.1.pdf」这种层级。
    if (directory != null && directory.isNotEmpty) {
      return super.saveToDownloads(
        fileName: fileName,
        bytes: bytes,
        directory: directory,
        mimeType: mimeType,
      );
    }
    // Android 走 MediaStore / DownloadManager，细节交给原生侧。
    // 原生侧回一个可读路径；没回（通道还没实现）就纯 Dart 落盘，
    // 至少文件真的存在，弹出的提示里也才有路径。
    final saved = await channel.invokeMethod<String>('saveToDownloads', {
      'fileName': fileName,
      'bytes': bytes,
      'mimeType': mimeType ?? 'application/octet-stream',
    });
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    return super.saveToDownloads(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
  }

  @override
  Future<Directory> downloadsDirectory() async {
    // 公共 Download 目录只有原生侧拿得到（Environment / MediaStore）；
    // 通道还没实现时会返回 null，继续往下退。
    final native = await invokePlatform<String>('downloadsDirectory');
    if (native != null && native.isNotEmpty) {
      final directory = Directory(native);
      try {
        await directory.create(recursive: true);
        return directory;
      } catch (_) {
        // 建不出来（分区/权限限制）就别停在死路上。
      }
    }

    // 退一步用应用专属外部目录：Scoped Storage 下不需要任何权限，
    // 路径也是文件管理器里能直接打开的真实路径。
    try {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        final directory = Directory(p.join(external.path, 'Downloads'));
        await directory.create(recursive: true);
        return directory;
      }
    } catch (_) {
      // 外部存储被卸载之类的情况，最后交给基类。
    }

    return super.downloadsDirectory();
  }

  @override
  Future<Map<String, String>> defaultRequestHeaders() async => const {
    'Referer': 'https://mis.bjtu.edu.cn/',
  };
}
