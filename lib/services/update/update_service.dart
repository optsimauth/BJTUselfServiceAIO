import 'dart:convert';

import 'package:package_info_plus/package_info_plus.dart';

import '../download/download_service.dart';
import '../../data/remote/api/update_api.dart';

class AppRelease {
  const AppRelease({
    required this.tagName,
    this.name = '',
    this.body = '',
    this.htmlUrl = '',
    this.publishedAt = '',
    this.assets = const [],
  });

  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final String publishedAt;
  final List<ReleaseAsset> assets;

  String get version => tagName.replaceFirst('v', '');
}

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    this.size = 0,
  });

  final String name;
  final String downloadUrl;
  final int size;
}

/// 版本检查 + 下载安装包。对应旧 GitRepository.fetchLatestRelease + UpdateScreen。
class UpdateService {
  UpdateService({
    required UpdateApi api,
    required DownloadService downloadService,
  }) : _api = api,
       _downloadService = downloadService;

  final UpdateApi _api;
  final DownloadService _downloadService;

  /// 返回新版本；已经是最新就返回 null。网络失败直接抛异常。
  Future<AppRelease?> checkForUpdate() async {
    final raw = await _api.fetchLatestReleaseRaw();
    final release = parseRelease(raw);
    final current = (await PackageInfo.fromPlatform()).version;
    return isNewer(releaseVersion: release.version, currentVersion: current)
        ? release
        : null;
  }

  Future<String> downloadRelease(AppRelease release) {
    final asset = release.assets.isEmpty ? null : release.assets.first;
    if (asset == null) {
      throw StateError('该版本没有可下载的安装包');
    }
    return _downloadService.download(
      url: asset.downloadUrl,
      fileName: asset.name,
      name: 'update.${release.version}',
    );
  }

  AppRelease parseRelease(String raw) {
    final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return AppRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt: json['published_at'] as String? ?? '',
      assets: (json['assets'] as List<dynamic>? ?? const []).map((item) {
        final asset = (item as Map).cast<String, dynamic>();
        return ReleaseAsset(
          name: asset['name'] as String? ?? '',
          downloadUrl: asset['browser_download_url'] as String? ?? '',
          size: asset['size'] as int? ?? 0,
        );
      }).toList(),
    );
  }

  /// 只比较数字段，忽略后缀（1.2.3-beta 也算 1.2.3）。
  bool isNewer({
    required String releaseVersion,
    required String currentVersion,
  }) {
    final release = _numericParts(releaseVersion);
    final current = _numericParts(currentVersion);
    for (var index = 0; index < release.length; index++) {
      final other = index < current.length ? current[index] : 0;
      if (release[index] != other) {
        return release[index] > other;
      }
    }
    return false;
  }

  List<int> _numericParts(String version) => version
      .split('.')
      .map((part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '') ?? 0)
      .toList();
}
