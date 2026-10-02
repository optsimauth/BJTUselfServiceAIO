import '../../../core/constants/api_constants.dart';
import '../../../core/network/request_manager.dart';

/// GitHub 仓库信息。用于展示项目 Star 变化。
class GithubApi {
  const GithubApi(this._request);

  final RequestManager _request;

  Future<String> fetchRepoRaw(String repository) => _request.getText(
        ApiConstants.githubRepoUrl(repository),
        headers: const {'Accept': 'application/vnd.github+json'},
      );
}
