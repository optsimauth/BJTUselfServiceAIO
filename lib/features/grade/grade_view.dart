import '../../data/models/grade/grade_model.dart';
import 'grade_score.dart';

/// 页面上一个成绩条目：原始成绩 + 是否被勾选。
///
/// 勾选是「自选课程计算」模式的事：勾上了一门，加权平均分就只算那几门。
/// 从控制器拿到的永远是「已经过筛选和排序」的条目，这里只做展示聚合。
class GradeView {
  const GradeView({required this.grade, required this.selected});

  final Grade grade;

  /// 这门课是否被用户勾选进「自选计算」范围。
  final bool selected;

  GradeScore get score => GradeScore.parse(grade.courseScore);

  /// 学期标签。教务没给标签时（`tag` 为空）显示「未标注学期」。
  String get semesterLabel {
    final tag = grade.tag.trim();
    return tag.isEmpty ? '未标注学期' : tag;
  }
}
