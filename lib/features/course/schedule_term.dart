/// 课表的学期视图。
///
/// 教务系统把课表拆成两个独立页面（本学期 / 历史课表），接口也没有
/// 「学期列表」这种可以直接枚举的东西，所以这里保持两态而不是搞成动态列表。
/// 后续如果接口开放了多学期，这里换成列表 + 该枚举退役即可，调用方只依赖
/// [ScheduleTerm.matches] 与 [ScheduleTerm.label]。
enum ScheduleTerm {
  current('本学期'),
  history('选课课表');

  const ScheduleTerm(this.label);

  /// 工具栏与持久化里展示的名字。
  final String label;

  /// 本学期 -> `Course.isCurrentSemester == true`。
  bool matches({required bool isCurrentSemester}) =>
      this == ScheduleTerm.current ? isCurrentSemester : !isCurrentSemester;

  /// 课程列表按学期过滤（与 [matches] 互为逆运算）。
  bool accepts({required bool isCurrentSemester}) =>
      matches(isCurrentSemester: isCurrentSemester);

  static ScheduleTerm fromIsCurrentSemester(bool isCurrentSemester) =>
      isCurrentSemester ? ScheduleTerm.current : ScheduleTerm.history;

  /// SharedPreferences 存储值。
  String get storageValue => name;

  static ScheduleTerm fromStorage(String? value) =>
      ScheduleTerm.values.firstWhere(
        (term) => term.name == value,
        orElse: () => ScheduleTerm.current,
      );
}
