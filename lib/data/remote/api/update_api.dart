import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';

/// 版本更新检查（GitHub Releases）。对应旧 GitRepository.fetchLatestRelease。
class UpdateApi {
  const UpdateApi(this._request);

  final RequestManager _request;

  Future<String> fetchLatestReleaseRaw() => _request.getText(
    ApiConstants.githubLatestReleaseUrl,
    headers: const {'Accept': 'application/vnd.github+json'},
  );
}
