// 暂时停用：只有 /web 路由用得到它，恢复时一起放开。
// import 'package:bjtuselfserviceaio/core/constants/api_constants.dart';
import 'package:bjtuselfserviceaio/features/account/account_page.dart';
import 'package:bjtuselfserviceaio/features/classroom/classroom_page.dart';
import 'package:bjtuselfserviceaio/features/course/course_schedule_page.dart';
import 'package:bjtuselfserviceaio/features/courseware/courseware_page.dart';
import 'package:bjtuselfserviceaio/features/detection/detection_page.dart';
import 'package:bjtuselfserviceaio/data/models/classroom/classroom_model.dart';
import 'package:bjtuselfserviceaio/features/email/email_page.dart';
import 'package:bjtuselfserviceaio/features/exam/exam_page.dart';
import 'package:bjtuselfserviceaio/features/grade/grade_page.dart';
import 'package:bjtuselfserviceaio/features/home/home_page.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_page.dart';
import 'package:bjtuselfserviceaio/features/login/login_page.dart';
import 'package:bjtuselfserviceaio/features/logs/logs_page.dart';
import 'package:bjtuselfserviceaio/features/other/other_function_page.dart';
import 'package:bjtuselfserviceaio/features/settings/settings_page.dart';
import 'package:bjtuselfserviceaio/features/space/space_page.dart';
// 暂时停用，配套的 lib/features/webview/ 整层代码一并保留。
// import 'package:bjtuselfserviceaio/features/webview/web_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'service_locator.dart';

/// 路由表 + 登录守卫。旧项目是 RouteManager + NavHost（13 个 destination）。
abstract final class AppRoutes {
  static const String home = '/home';
  static const String space = '/space';
  static const String settings = '/settings';

  static const String login = '/login';
  static const String course = '/course';
  static const String grade = '/grade';
  static const String exam = '/exam';
  static const String homework = '/homework';
  static const String courseware = '/courseware';
  static const String classroom = '/classroom';
  static const String detection = '/detection';
  static const String account = '/account';
  static const String email = '/email';
  static const String other = '/other';
  static const String web = '/web';

  /// 日志页，没有主导航入口，只从设置页进。
  static const String logs = '/logs';

  /// 教室占用课表。路径参数是教务 `jxlh` 的数字 ID，不是中文楼名 ——
  /// 中文字符进路径要转义，深链和网页端都容易对不上。
  static String classroomDetail(ClassroomBuilding building) =>
      '/classroom/${building.id}';
}

GoRouter createAppRouter(ServiceLocator locator) {
  final account = locator.accountRepository;
  return GoRouter(
    // 冷启动直接进主页：本地数据在 bootstrap 里已经 hydrate 完，登录在背后跑。
    initialLocation: AppRoutes.home,
    // 会话状态一变就重新评估守卫（手动登录成功要自己走出登录页）。
    refreshListenable: account.sessionState,
    redirect: (context, state) => loginRedirect(
      hasCredentials: account.hasCredentials,
      isLoggedIn: account.isLoggedIn,
      location: state.matchedLocation,
    ),
    routes: [
      // 底部三个 tab 用 indexedStack 保活，切回来不重新加载。
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.space,
                builder: (context, state) => const SpacePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.course,
        builder: (context, state) => const CourseSchedulePage(),
      ),
      GoRoute(
        path: AppRoutes.grade,
        builder: (context, state) => const GradePage(),
      ),
      GoRoute(
        path: AppRoutes.exam,
        builder: (context, state) => const ExamPage(),
      ),
      GoRoute(
        path: AppRoutes.homework,
        builder: (context, state) => const HomeworkPage(),
      ),
      GoRoute(
        path: AppRoutes.courseware,
        builder: (context, state) => const CoursewarePage(),
      ),
      GoRoute(
        path: '${AppRoutes.classroom}/:building',
        builder: (context, state) {
          // 认不出这串 ID（教学楼被删 / 手改了链接）就退回列表页，
          // 硬开第一栋楼等于给用户看一栋他没点的楼的数据。
          final building = ClassroomBuildings.byId(
            state.pathParameters['building'] ?? '',
          );
          return building == null
              ? const DetectionPage()
              : ClassroomPage(building: building);
        },
      ),
      GoRoute(
        path: AppRoutes.detection,
        builder: (context, state) => const DetectionPage(),
      ),
      GoRoute(
        path: AppRoutes.account,
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: AppRoutes.email,
        builder: (context, state) => const EmailPage(),
      ),
      GoRoute(
        path: AppRoutes.other,
        builder: (context, state) => const OtherFunctionPage(),
      ),
// 暂时停用：Windows 上 WebView2 纹理合成仍会白屏 / 吞点击，定位完再放开。
      // GoRoute(
      //   path: AppRoutes.web,
      //   builder: (context, state) => WebPage(
      //     url: state.uri.queryParameters['url'] ?? ApiConstants.misHomeUrl,
      //     title: state.uri.queryParameters['title'] ?? '网页版',
      //   ),
      // ),
      GoRoute(
        path: AppRoutes.logs,
        builder: (context, state) => const LogsPage(),
      ),
    ],
  );
}

/// 登录守卫，就两条：
/// 1. 本地有凭据 -> 一律放行进主页，登录成不成功都让用户先看本地数据；
/// 2. 本地没凭据（第一次用 / 已退出） -> 只能停在登录页；手动登录成功再自己走出去。
@visibleForTesting
String? loginRedirect({
  required bool hasCredentials,
  required bool isLoggedIn,
  required String location,
}) {
  if (!hasCredentials) {
    return location == AppRoutes.login ? null : AppRoutes.login;
  }
  if (isLoggedIn && location == AppRoutes.login) {
    return AppRoutes.home;
  }
  return null;
}

/// 底部导航外壳（旧 MainActivity 的 NavigationBar）。
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<NavigationDestination> destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: '首页',
    ),
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view),
      label: '应用',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: destinations,
        onDestinationSelected: (index) {
          // 切 tab 轻轻一下：手指不盯着屏幕也知道按到了。
          HapticFeedback.selectionClick();
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
