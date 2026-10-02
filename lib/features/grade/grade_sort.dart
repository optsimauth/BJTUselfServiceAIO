import '../../data/models/grade/grade_model.dart';
import 'grade_score.dart';

/// 列表排序。成绩「原始顺序」是数据库顺序（一般按学期排），
/// 升 / 降序都按成绩数字排。
enum GradeSortOrder {
  original('原始顺序'),
  ascending('从低到高'),
  descending('从高到低');

  const GradeSortOrder(this.label);

  /// 排序方向的中文名，sort 按钮的 tooltip 用。
  final String label;
}

extension GradeSorting on GradeSortOrder {
  /// 排序结果。没出分的课（`-,-`）永远沉底并保持彼此原始顺序 ——
  /// 升序时不该把「还没出分」排在 0 分前面，两种方向都统一放最后。
  List<Grade> apply(List<Grade> grades) {
    if (this == GradeSortOrder.original) {
      return grades;
    }
    final scored = <Grade>[];
    final unscored = <Grade>[];
    for (final grade in grades) {
      final numeric = GradeScore.parse(grade.courseScore).numeric;
      if (numeric == null) {
        unscored.add(grade);
      } else {
        scored.add(grade);
      }
    }
    scored.sort((a, b) {
      final aScore = GradeScore.parse(a.courseScore).numeric!;
      final bScore = GradeScore.parse(b.courseScore).numeric!;
      return this == GradeSortOrder.ascending
          ? aScore.compareTo(bScore)
          : bScore.compareTo(aScore);
    });
    return [...scored, ...unscored];
  }
}
