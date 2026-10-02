import 'dart:io';

import 'android/android_platform_service.dart';
import 'ios/ios_platform_service.dart';
import 'macos/macos_platform_service.dart';
import 'windows/windows_platform_service.dart';

enum PlatformKind { android, ios, windows, macos, linux }

/// 平台差异的唯一出口：业务代码不许写 Platform.isAndroid，需要差异就扩展这里。
abstract interface class PlatformService {
  PlatformKind get kind;

  /// 可写的数据目录（下载、缓存、课件）。
  Future<Directory> appDataDirectory();

  Future<Directory> tempDirectory();

  /// 系统下载目录（设置里没选下载位置时用它）。
  ///
  /// 上层要往下载目录里拼子目录（app 那一层文件夹、课件的课程目录），
  /// 而拼路径必须知道落点，所以这个方法从平台层暴露出来。
  Future<Directory> downloadsDirectory();

  Future<List<String>> pickFiles({List<String> extensions});

  /// 存到 [directory]（绝对路径，可含子目录，会自动创建）。
  /// [directory] 为 null 时存到系统默认下载目录。
  /// 返回落盘后的完整路径，null = 平台那边没报回来。
  Future<String?> saveToDownloads({
    required String fileName,
    required List<int> bytes,
    String? directory,
    String? mimeType,
  });

  Future<bool> openFile(String path);

  Future<bool> openUrl(String url);

  Future<void> notify({required String title, required String body});

  /// 课程表小组件（旧项目是 AppWidget + CourseScheduleWidget）。
  Future<void> refreshHomeWidget(Map<String, Object?> payload);

  /// 平台特有的请求头。
  Future<Map<String, String>> defaultRequestHeaders();
}

/// 按当前运行平台挑选实现。
abstract final class PlatformServiceFactory {
  static PlatformService create() {
    if (Platform.isAndroid) {
      return AndroidPlatformService();
    }
    if (Platform.isIOS) {
      return IosPlatformService();
    }
    if (Platform.isWindows) {
      return WindowsPlatformService();
    }
    if (Platform.isMacOS) {
      return MacosPlatformService();
    }
    return WindowsPlatformService();
  }
}
