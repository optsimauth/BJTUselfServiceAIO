import 'package:flutter/foundation.dart';

import '../../data/models/grade/grade_model.dart';

/// 学期筛选。空集合 = 全部。
///
/// 筛选依据是成绩的 `tag`（学年学期，例如 `2025-2026-1`）。因为过滤是
/// 多选的（能不能只看这几学期），这里存的是被选中的 tag 集合。
class GradeSemesterFilter {
  const GradeSemesterFilter({this.semesters = const <String>{}});

  static const GradeSemesterFilter all = GradeSemesterFilter();

  /// 被选中的学期 tag。
  final Set<String> semesters;

  bool get isAll => semesters.isEmpty;

  bool matches(Grade grade) => isAll || semesters.contains(grade.tag);

  /// 点一下「已选 / 未选」来回切换某个学期。
  GradeSemesterFilter toggled(String semester) {
    final next = Set<String>.of(semesters);
    if (!next.add(semester)) {
      next.remove(semester);
    }
    return GradeSemesterFilter(semesters: next);
  }

  GradeSemesterFilter clear() => all;

  @override
  bool operator ==(Object other) =>
      other is GradeSemesterFilter && setEquals(other.semesters, semesters);

  @override
  int get hashCode => Object.hashAllUnordered(semesters);
}
