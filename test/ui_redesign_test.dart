import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:bjtuselfserviceaio/app/app_navigation.dart';
import 'package:bjtuselfserviceaio/data/models/account/account_status.dart';
import 'package:bjtuselfserviceaio/data/models/course/course_model.dart';
import 'package:bjtuselfserviceaio/data/mock/mock_lists.dart';
import 'package:bjtuselfserviceaio/data/models/grade/grade_model.dart';
import 'package:bjtuselfserviceaio/data/models/exam/exam_model.dart';
import 'package:bjtuselfserviceaio/data/models/homework/homework_model.dart';
import 'package:bjtuselfserviceaio/data/models/courseware/courseware_model.dart';
import 'package:bjtuselfserviceaio/data/repositories/grade_repository.dart';
import 'package:bjtuselfserviceaio/data/repositories/exam_repository.dart';
import 'package:bjtuselfserviceaio/data/repositories/homework_repository.dart';
import 'package:bjtuselfserviceaio/data/repositories/courseware_repository.dart';
import 'package:bjtuselfserviceaio/features/grade/grade_controller.dart';
import 'package:bjtuselfserviceaio/features/grade/grade_page.dart';
import 'package:bjtuselfserviceaio/features/exam/exam_controller.dart';
import 'package:bjtuselfserviceaio/features/exam/exam_page.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_controller.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_page.dart';
import 'package:bjtuselfserviceaio/features/courseware/courseware_page.dart';
import 'package:bjtuselfserviceaio/features/login/login_page.dart';
import 'package:bjtuselfserviceaio/features/space/space_page.dart';
import 'package:bjtuselfserviceaio/features/home/home_page.dart';
import 'package:bjtuselfserviceaio/features/home/home_controller.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:bjtuselfserviceaio/shared/theme/colors.dart';
import 'package:bjtuselfserviceaio/app/service_locator.dart';
import 'package:bjtuselfserviceaio/core/storage/preferences.dart';
import 'package:bjtuselfserviceaio/data/models/account/account_model.dart';
import 'package:bjtuselfserviceaio/data/models/email/email_models.dart';
import 'package:bjtuselfserviceaio/data/remote/api/email_api.dart';
import 'package:bjtuselfserviceaio/data/repositories/account_repository.dart';
import 'package:bjtuselfserviceaio/data/repositories/github_repository.dart';
import 'package:bjtuselfserviceaio/features/account/account_page.dart';
import 'package:bjtuselfserviceaio/features/settings/settings_page.dart';
import 'package:bjtuselfserviceaio/features/detection/detection_page.dart';
import 'package:bjtuselfserviceaio/features/other/other_function_page.dart';
import 'package:bjtuselfserviceaio/features/logs/logs_page.dart';
import 'package:bjtuselfserviceaio/features/github/star_page.dart';
import 'package:bjtuselfserviceaio/features/email/email_page.dart';
import 'package:bjtuselfserviceaio/features/email/email_controller.dart';
import 'package:bjtuselfserviceaio/shared/widgets/app_status_view.dart';
import 'package:bjtuselfserviceaio/shared/widgets/cards/app_card.dart';

/// 截图是「人工复查用的产物」，不是断言的一部分。
///
/// 默认不截图：`flutter test` 只验证布局（无溢出、无异常）。需要看图时显式打开：
/// `UI_REVIEW=1 flutter test test/ui_redesign_test.dart`。
/// 复查模式加载实际中文字体；普通布局断言使用 Flutter 默认测试字体。
final bool _reviewMode = Platform.environment['UI_REVIEW'] == '1';

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!_reviewMode) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      // 图片是原生资源，不释放会随用例数累积。
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
    if (!_reviewMode) return;
    final loader = FontLoader('NotoSansSC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansSC-VF.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final (name, size) in [
    ('small-phone', const Size(360, 640)),
    ('phone', const Size(360, 800)),
    ('large-phone', const Size(412, 915)),
    ('tablet', const Size(820, 1180)),
    ('desktop', const Size(1440, 900)),
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$name ${dark ? "dark" : "light"} $scale：登录与服务页完整渲染无溢出', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          final theme = dark ? AppTheme.dark() : AppTheme.light();
          Widget app(Widget child) => MaterialApp(
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: RepaintBoundary(key: key, child: child),
            ),
          );
          await tester.pumpWidget(app(LoginView(onLogin: (_) async {})));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await _capture(
              tester,
              key,
              'login-$name-${dark ? "dark" : "light"}',
            );
          }
          await tester.pumpWidget(
            app(
              Scaffold(
                appBar: AppBar(title: const Text('今日校园')),
                body: HomeDashboard(
                  // 截图用的样例数值：状态条在真机上来自 MIS 状态接口。
                  summary: const HomeSummary(
                    currentWeek: 7,
                    todayCourses: [
                      Course(
                        courseId: 'ui-review-course',
                        name: '概率论与数理统计（课程设计与习题讨论）',
                        teacher: '张老师',
                        place: '理学楼 404',
                        time: '1-16周',
                        locationIndex: 57,
                      ),
                    ],
                    status: AccountStatus(
                      ecardBalance: '86.40',
                      netBalance: '12.00',
                      unreadMail: 2,
                    ),
                  ),
                  onRefresh: () async {},
                  changes: const SizedBox.shrink(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await _capture(
              tester,
              key,
              'home-$name-${dark ? "dark" : "light"}',
            );
          }
          await tester.pumpWidget(
            app(
              AppNavigation(
                index: 1,
                onSelected: (_) {},
                child: const SpacePage(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('课程表'), findsOneWidget);
          expect(
            find.byType(NavigationRail),
            size.width >= 600 ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(NavigationBar),
            size.width < 600 ? findsOneWidget : findsNothing,
          );
          if (scale == 1 || name == 'phone') {
            await _capture(
              tester,
              key,
              'services-$name-${dark ? "dark" : "light"}-$scale',
            );
          }
          await tester.scrollUntilVisible(
            find.text('邮箱'),
            250,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text('邮箱'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      for (final width in [360.0, 1440.0]) {
        testWidgets(
          '业务页 $width ${dark ? "dark" : "light"} $scale：成绩、考试、作业与课件',
          (tester) async {
            final size = Size(width, 800);
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final grades = GradeController(repository: _Grades());
            final exams = ExamController(repository: _Exams());
            final homework = HomeworkController(repository: _Homework());
            addTearDown(grades.dispose);
            addTearDown(exams.dispose);
            addTearDown(homework.dispose);
            await Future.wait([
              grades.hydrate(),
              exams.hydrate(),
              homework.hydrate(),
            ]);
            final now = DateTime(2026, 10, 25, 10);
            for (final (name, page) in <(String, Widget)>[
              ('grades', GradePage(controller: grades)),
              ('exams', ExamPage(controller: exams, now: now)),
              ('homework', HomeworkPage(controller: homework, now: now)),
              ('courseware', CoursewarePage(repository: _Courseware())),
            ]) {
              final key = GlobalKey();
              await tester.pumpWidget(
                MaterialApp(
                  theme: dark ? AppTheme.dark() : AppTheme.light(),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: true,
                    ),
                    child: RepaintBoundary(key: key, child: page),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: name);
              if (name != 'courseware') {
                final summaryKey = switch (name) {
                  'grades' => 'grade-gpa',
                  'exams' => 'exam-summary',
                  _ => 'homework-summary',
                };
                final summaryFinder = find.byKey(ValueKey(summaryKey));
                final summary = tester.widget<Container>(summaryFinder);
                final decoration = summary.decoration! as BoxDecoration;
                final scheme = Theme.of(tester.element(summaryFinder))
                    .colorScheme;
                expect(decoration.gradient, isNull, reason: '$name 摘要应为实色面板');
                expect(decoration.color, scheme.surfaceContainerLow);
                expect(decoration.border, isNotNull);
                for (final text in tester.widgetList<Text>(
                  find.descendant(
                    of: summaryFinder,
                    matching: find.byType(Text),
                  ),
                )) {
                  expect(
                    AppColors.contrast(text.style!.color!, decoration.color!),
                    greaterThanOrEqualTo(4.5),
                    reason: '$name 摘要文字 ${text.data} 必须可读',
                  );
                }
              }
              if (name == 'courseware') {
                await tester.tap(find.text(MockList.coursewares.first.name));
                await tester.pumpAndSettle();
                expect(find.byType(AnimatedSize), findsNothing);
                expect(
                  find.text(MockList.coursewares.first.children.first.name),
                  findsWidgets,
                );
                expect(tester.takeException(), isNull);
              }
              await _capture(
                tester,
                key,
                '$name-$width-${dark ? "dark" : "light"}-$scale',
              );
              if (name == 'grades') {
                grades.scrollController.jumpTo(
                  grades.scrollController.position.maxScrollExtent,
                );
                await tester.pumpAndSettle();
                // 回顶 FAB 要滚过 300px 才出现：1440 宽下同 10 条假数据
                // 卡片不换行、整体不够长，这时候没有 FAB 是正常的
                // （窄屏下同数据够长，走的就是下面这条完整断言）。
                final fab = find.byType(FloatingActionButton);
                if (fab.evaluate().isNotEmpty) {
                  await tester.tap(fab);
                  await tester.pumpAndSettle();
                  expect(grades.scrollController.offset, 0);
                }
                expect(tester.takeException(), isNull);
              }
              await tester.pumpWidget(const SizedBox.shrink());
            }
          },
        );
      }
    }
  }

  for (final width in [360.0, 1440.0]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('全项目补充页面 $width $dark $scale：统一布局无溢出', (tester) async {
          SharedPreferences.setMockInitialValues({});
          final services = _UiServices(await AppPreferences.open());
          addTearDown(services.preferences.dispose);
          addTearDown(services.accountRepository.sessionState.dispose);
          addTearDown(services.emailController.dispose);
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          for (final (name, page) in <(String, Widget)>[
            ('account', const AccountPage()),
            ('settings', const SettingsPage()),
            ('buildings', const DetectionPage()),
            ('tools', const OtherFunctionPage()),
            ('logs', const LogsPage()),
            ('stars', const StarPage()),
            ('email', const EmailPage()),
          ]) {
            final key = GlobalKey();
            await tester.pumpWidget(
              ServiceScope(
                locator: services,
                child: MaterialApp(
                  theme: dark ? AppTheme.dark() : AppTheme.light(),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 900),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: RepaintBoundary(key: key, child: page),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$name $width $dark $scale',
            );
            if (scale == 1) {
              await _capture(
                tester,
                key,
                '$name-$width-${dark ? "dark" : "light"}',
              );
            }
            await tester.pumpWidget(const SizedBox.shrink());
          }
        });
      }
    }
  }

  testWidgets('分组面板与状态页在大字号下可滚动，恢复操作可点击', (tester) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: AppStatusView(
              icon: Icons.error_outline,
              title: '连接暂时不可用',
              message: '检查校园网络后重试，已保存的数据仍可离线查看。',
              action: FilledButton(
                onPressed: () => retries++,
                child: const Text('重试'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: AppSection(
              title: '账号资料',
              children: [
                ListTile(title: Text('姓名')),
                ListTile(title: Text('学院')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Card), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('登录表单不预填密码，校验输入，提交期间禁止重复并显示可恢复错误', (tester) async {
    final result = Completer<void>();
    var submissions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LoginView(
          initialUsername: 'test-student',
          onLogin: (credentials) {
            submissions++;
            expect(credentials.username, 'test-student');
            expect(credentials.password, 'test-password');
            return result.future;
          },
        ),
      ),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).last, 'test-password');
    await tester.pump();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(submissions, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    result.completeError(Exception('请检查学号和密码'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请检查学号和密码'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('服务目录可进入对应页面，导航目的地回调一致', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SpacePage()),
        GoRoute(
          path: '/course',
          builder: (_, _) => const Scaffold(body: Text('课程详情')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.tap(find.text('课程表'));
    await tester.pumpAndSettle();
    expect(find.text('课程详情'), findsOneWidget);
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: AppNavigation(
          index: 0,
          onSelected: (value) => selected = value,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.text('服务'));
    expect(selected, 1);
  });
}

// 复用现有样例，仅注入测试；应用的 MockList.enabled 保持 false。
class _Grades extends Fake implements GradeRepository {
  @override
  Stream<List<Grade>> watchAll() => Stream.value(MockList.grades);
}

class _Exams extends Fake implements ExamRepository {
  @override
  Stream<List<ExamSchedule>> watchAll() => Stream.value(MockList.exams);
}

class _Homework extends Fake implements HomeworkRepository {
  @override
  Stream<List<Homework>> watchAll() => Stream.value(MockList.homeworks);
}

class _Courseware extends Fake implements CoursewareRepository {
  @override
  List<CoursewareNode> loadCachedTree() => MockList.coursewares;
  @override
  Future<List<CoursewareNode>> refreshTree() async => MockList.coursewares;
}

class _UiServices extends Fake implements ServiceLocator {
  _UiServices(this.preferences);
  @override
  final AppPreferences preferences;
  @override
  final _UiAccount accountRepository = _UiAccount();
  @override
  final GithubRepository githubRepository = _UiGithub();
  @override
  final EmailController emailController = EmailController(api: _UiMail());
}

class _UiAccount extends Fake implements AccountRepository {
  @override
  final ValueNotifier<SessionState> sessionState = ValueNotifier(
    SessionState.loggedIn,
  );
  @override
  Future<StudentProfile> fetchStudentProfile() async => const StudentProfile(
    studentId: '2026000000',
    name: '界面预览',
    college: '计算机与信息技术学院',
    major: '计算机科学与技术（长名称与大字号验证）',
    className: '计算机 2601',
  );
}

class _UiGithub extends Fake implements GithubRepository {
  @override
  Future<RepoSnapshot> fetchSnapshot(String repository) async => RepoSnapshot(
    stars: 128,
    forks: 16,
    openIssues: 3,
    description: '校园生活服务工具（界面预览样例）',
    history: [StarPoint(at: DateTime(2026, 10, 25), count: 128)],
  );
}

class _UiMail extends Fake implements EmailApi {
  @override
  Future<MailboxPageResult> listMessages({
    required int folderId,
    int start = 0,
    int limit = 20,
  }) async => MailboxPageResult(
    totalCount: 1,
    messages: [
      MailSummary(
        id: 'ui-preview',
        folderId: folderId,
        sender: '教务通知',
        subject: '关于课程安排与学期选课的通知',
        preview: '请查看本周课程安排与选课时间。',
        dateText: '2026-10-25 10:00',
      ),
    ],
  );
}
