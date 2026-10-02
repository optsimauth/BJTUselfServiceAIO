import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bjtuselfserviceaio/core/constants/app_constants.dart';
import 'package:bjtuselfserviceaio/core/storage/preferences.dart';
import 'package:bjtuselfserviceaio/data/repositories/github_repository.dart';

/// 只用真实 SharedPreferences，仓库里没有依赖注入口能塞假 API，
/// 所以这里测的是「历史怎么存、怎么算变化」这部分纯逻辑。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await AppPreferences.open();
  });

  test('没记过时历史是空的，不报错', () {
    expect(GithubRepository.loadHistoryOf(preferences), isEmpty);
  });

  test('缓存结构坏了就当没记过，不让整页崩掉', () async {
    await preferences.writeString(StorageKeys.githubStarHistory, 'not json');
    expect(GithubRepository.loadHistoryOf(preferences), isEmpty);
  });

  test('历史按时间升序读回来', () async {
    final raw = [
      {'t': 3000, 'v': 30},
      {'t': 1000, 'v': 10},
      {'t': 2000, 'v': 20},
    ];
    await preferences.writeString(StorageKeys.githubStarHistory, jsonEncode(raw));

    final history = GithubRepository.loadHistoryOf(preferences);
    expect(history.map((point) => point.count), [10, 20, 30]);
  });

  group('变化量', () {
    RepoSnapshot of(List<int> counts) => RepoSnapshot(
          stars: counts.last,
          forks: 0,
          openIssues: 0,
          history: [
            for (var i = 0; i < counts.length; i++)
              StarPoint(at: DateTime(2026, 1, 1).add(Duration(hours: i)), count: counts[i]),
          ],
        );

    test('只有一个采样点时 delta 是 0，不假装知道涨了多少', () {
      expect(of([42]).delta, 0);
      expect(of([42]).totalDelta, 0);
    });

    test('delta 是相对上一次，totalDelta 是相对第一次', () {
      final snapshot = of([10, 25, 40]);
      expect(snapshot.delta, 15);
      expect(snapshot.totalDelta, 30);
    });

    test('掉星也算变化，负数如实显示', () {
      final snapshot = of([40, 30]);
      expect(snapshot.delta, -10);
      expect(snapshot.totalDelta, -10);
    });
  });
}
