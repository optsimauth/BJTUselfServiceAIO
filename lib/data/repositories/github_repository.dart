import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/preferences.dart';
import '../remote/api/github_api.dart';

/// 一次 Star 采样：某个时刻的星数。
@immutable
class StarPoint {
  const StarPoint({required this.at, required this.count});

  /// 采样时刻。
  final DateTime at;
  final int count;

  Map<String, dynamic> toJson() => {
        't': at.millisecondsSinceEpoch,
        'v': count,
      };

  factory StarPoint.fromJson(Map<String, dynamic> json) => StarPoint(
        at: DateTime.fromMillisecondsSinceEpoch(
          (json['t'] as num?)?.toInt() ?? 0,
        ),
        count: (json['v'] as num?)?.toInt() ?? 0,
      );
}

/// 仓库当前状态 + Star 变化历史。
@immutable
class RepoSnapshot {
  const RepoSnapshot({
    required this.stars,
    required this.forks,
    required this.openIssues,
    required this.history,
    this.description = '',
    this.htmlUrl = '',
  });

  final int stars;
  final int forks;
  final int openIssues;

  /// 按时间升序。至少含本次采样。
  final List<StarPoint> history;

  final String description;
  final String htmlUrl;

  /// 最新一次采样。
  StarPoint get latest => history.last;

  /// 比上一次采样多了多少颗。没上一次（刚装）就是 0。
  int get delta => history.length < 2 ? 0 : latest.count - history[history.length - 2].count;

  /// 比第一次采样多了多少颗。
  int get totalDelta => history.isEmpty ? 0 : latest.count - history.first.count;
}

/// GitHub 仓库信息。Star 的「变化」是本地记下来的历史 ——
/// GitHub 的 API 只给当前值，不给历史曲线，所以每开一次页面就存一个点。
class GithubRepository {
  GithubRepository({
    required GithubApi api,
    required AppPreferences preferences,
  })  : _api = api,
        _preferences = preferences;

  /// 历史最多留这么多个点。超了从最老的开始丢。
  static const int maxPoints = 180;

  /// 同一天内重复打开不重复记点，否则一天刷 50 次就是一条陡峭的假曲线。
  static const Duration sampleInterval = Duration(hours: 12);

  final GithubApi _api;
  final AppPreferences _preferences;

  /// 已记录的历史（不含本次采样），时间升序。
  List<StarPoint> loadHistory() => loadHistoryOf(_preferences);

  /// 读历史。做成 static 是为了能脱离网络依赖单测 —— 这个类没有可注入口，
  /// 测试没法塞一个假 API 进来，但「历史怎么存、坏了怎么办」是纯逻辑，值得测。
  static List<StarPoint> loadHistoryOf(AppPreferences preferences) {
    final raw = preferences.readString(StorageKeys.githubStarHistory);
    if (raw.isEmpty) return const [];
    try {
      final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return decoded.map(StarPoint.fromJson).toList()..sort(_byTime);
    } catch (_) {
      // 缓存结构变了就当没记过，重新开始。
      return const [];
    }
  }

  /// 拉当前值，存一个采样点，返回带历史的快照。
  Future<RepoSnapshot> fetchSnapshot(String repository) async {
    final json = _parseRepo(await _api.fetchRepoRaw(repository));
    final now = DateTime.now();
    final history = [...loadHistory()];

    // 距离上一个点够久、或者星数真的变了，才记一个新点。
    if (history.isEmpty ||
        now.difference(history.last.at) >= sampleInterval ||
        history.last.count != json.stars) {
      history.add(StarPoint(at: now, count: json.stars));
      if (history.length > maxPoints) {
        history.removeRange(0, history.length - maxPoints);
      }
      await _preferences.writeString(
        StorageKeys.githubStarHistory,
        jsonEncode(history.map((point) => point.toJson()).toList()),
      );
    }

    return RepoSnapshot(
      stars: json.stars,
      forks: json.forks,
      openIssues: json.openIssues,
      history: history,
      description: json.description,
      htmlUrl: json.htmlUrl,
    );
  }

  static int _byTime(StarPoint a, StarPoint b) => a.at.compareTo(b.at);

  static _RepoFields _parseRepo(String raw) {
    final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return _RepoFields(
      stars: (json['stargazers_count'] as num?)?.toInt() ?? 0,
      forks: (json['forks_count'] as num?)?.toInt() ?? 0,
      openIssues: (json['open_issues_count'] as num?)?.toInt() ?? 0,
      description: (json['description'] as String?) ?? '',
      htmlUrl: (json['html_url'] as String?) ?? '',
    );
  }
}

class _RepoFields {
  const _RepoFields({
    required this.stars,
    required this.forks,
    required this.openIssues,
    required this.description,
    required this.htmlUrl,
  });

  final int stars;
  final int forks;
  final int openIssues;
  final String description;
  final String htmlUrl;
}
