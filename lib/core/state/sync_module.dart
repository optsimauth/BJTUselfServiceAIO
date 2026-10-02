enum SyncModule {
  course('课表'),
  grade('成绩'),
  exam('考试'),
  homework('作业'),
  courseware('课件');

  const SyncModule(this.label);

  final String label;
}
