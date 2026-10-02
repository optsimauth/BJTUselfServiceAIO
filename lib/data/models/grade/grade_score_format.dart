/// 成绩字符串的「存储格式」。
///
/// 成绩列进来的时候可能是 `95`（数字）、`A-`（等级）或 `优秀`（写了字），
/// 解析端统一规整成 `等级,分数`（例如 `A,95` / `优秀,95`），保证上层看到的
/// `courseScore` 永远同一种形状：逗号前是等级、逗号后是能参与加权计算的数字。
///
/// 规整规则照抄旧项目 `Utils.convertAndFormatGradeScore`：数字按分档转等级，
/// 等级找映射表拿分数，两种都不是就落 `-,-`（「没出分」）。多加一条幂等保护：
/// 已经是 `等级,数字` 的保持原样，解析两端（HTML 与 JSON）各套一次也不会坏。
abstract final class GradeScoreFormat {
  /// 等级 -> 分数。旧 `Utils.gradeToScoreMap`。
  static const Map<String, int> letterToScore = {
    'A': 95,
    'A-': 87,
    'B+': 83,
    'B': 79,
    'B-': 76,
    'C+': 73,
    'C': 69,
    'C-': 66,
    'D+': 63,
    'D': 60,
    'F': 30,
  };

  static String format(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty || cleaned == '-,-') {
      return '-,-';
    }
    // 幂等：`A,95` / `优秀,95` 这类已经规整过的不动。
    if (RegExp(r'^[^0-9]+,\d+(\.\d+)?$').hasMatch(cleaned)) {
      return cleaned;
    }
    final score = int.tryParse(cleaned);
    if (score != null) {
      return '${scoreToLetter(score)},$score';
    }
    final mapped = letterToScore[cleaned];
    if (mapped != null) {
      return '$cleaned,$mapped';
    }
    return '-,-';
  }

  /// 分数 -> 等级。旧 `Utils.scoreToGrade`。
  static String scoreToLetter(int score) {
    if (score >= 90) return 'A';
    if (score >= 85) return 'A-';
    if (score >= 81) return 'B+';
    if (score >= 78) return 'B';
    if (score >= 75) return 'B-';
    if (score >= 71) return 'C+';
    if (score >= 68) return 'C';
    if (score >= 65) return 'C-';
    if (score >= 61) return 'D+';
    if (score == 60) return 'D';
    return 'F';
  }
}
