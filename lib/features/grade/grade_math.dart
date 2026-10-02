import '../../data/models/grade/grade_model.dart';
import 'grade_score.dart';

/// 加权平均分。口径跟旧代码一致：成绩数字 × 学分 求和，除以学分和。
///
/// 成绩读不出来（`-,-`）或者学分为非正数（0.0 / 空）的课不参与，
/// 既不算进分子也不往下拖平均 —— 教务处没出分的课不该把均分拽低。
/// 全部不参与时 [average] 为 null，界面显示「还没出分」而不是 0。
class GradeGpa {
  const GradeGpa({required this.average, required this.countedCourses});

  final double? average;

  /// 实际参与计算的课程门数。
  final int countedCourses;
}

GradeGpa gpaOf(Iterable<Grade> grades) {
  var weightedSum = 0.0;
  var creditSum = 0.0;
  var counted = 0;
  for (final grade in grades) {
    final score = GradeScore.parse(grade.courseScore).numeric;
    final credit = double.tryParse(grade.courseCredits);
    if (score == null || credit == null || credit <= 0) {
      continue;
    }
    weightedSum += score * credit;
    creditSum += credit;
    counted++;
  }
  return GradeGpa(
    average: creditSum == 0 ? null : weightedSum / creditSum,
    countedCourses: counted,
  );
}

/// 平均分对应的评语，抄旧项目 GpaCard 的口号（分档也是它的）。
String gradeCommentFor(double score) {
  if (score >= 92.5) return '🫢 这位学霸会不会太猛了';
  if (score >= 87.5) return '🫡 鼓足干劲，力争上游，多快好省地，加油吧！！！';
  if (score >= 82.5) return '☺️ 还可以哦，再加把劲吧～';
  if (score >= 70) return '🥹 不错哦，继续努力';
  if (score >= 60) return '😃 得加把劲了，但或许已经够了？';
  return '😱😱😱 同学你真得加油了啊';
}
