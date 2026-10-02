/// 成绩字符串（`A,95` / `优秀,95` / `-,-`）的展示解析。
///
/// 存储层（`GradeScoreFormat`）保证 `courseScore` 永远是「等级,数字」的形状，
/// 这里只负责把两半拆开并取出能参与计算的数字。`-,-` 表示还没出分，
/// [numeric] 为 null，界面上不能拿它算加权、也不该显示成 0 分。
class GradeScore {
  const GradeScore({required this.letter, this.numeric});

  /// 逗号前的等级段（`A` / `优秀` / `-`）。没解析出来就是空串。
  final String letter;

  /// 逗号后的数字段；`-,-` 或解析失败时为 null。
  final double? numeric;

  bool get isKnown => numeric != null;

  static GradeScore parse(String courseScore) {
    final parts = courseScore.split(',');
    final letter = parts.isNotEmpty ? parts.first.trim() : '';
    // 正常是「等级,数字」；万一哪条数据只存了个裸数字，也兜得住。
    final numericValue = parts.length > 1
        ? parts[1].trim()
        : parts.first.trim();
    final numeric = double.tryParse(numericValue);
    return GradeScore(letter: letter, numeric: numeric);
  }
}
