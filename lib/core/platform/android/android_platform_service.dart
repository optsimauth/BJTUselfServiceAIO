import 'dart:io';

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
    // ponytail: 公共下载目录要走原生（Environment / MediaStore），通道还没实现。
    // 真接上时把这里换成 channel.invokeMethod('downloadsDirectory')。
    return super.downloadsDirectory();
  }

  @override
  Future<Map<String, String>> defaultRequestHeaders() async => const {
    'Referer': 'https://mis.bjtu.edu.cn/',
  };
}
