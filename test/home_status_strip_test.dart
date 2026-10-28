// 首页状态条：余额与未读邮件的展示规则，以及 2 倍字号下不挤成一团。
import 'package:bjtuselfserviceaio/data/models/account/account_status.dart';
import 'package:bjtuselfserviceaio/data/repositories/account_repository.dart';
import 'package:bjtuselfserviceaio/features/home/home_controller.dart';
import 'package:bjtuselfserviceaio/features/home/home_page.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _pump(
  WidgetTester tester,
  AccountStatus? status, {
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: HomeDashboard(
            summary: HomeSummary(currentWeek: 7, status: status),
            onRefresh: () async {},
            changes: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));

  testWidgets('登录状态提示条随大字号增高，恢复期间不可重复点击，成功后收起', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = ValueNotifier(SessionState.loggedOut);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Column(children: [HomeSessionBanner(listenable: state)]),
          ),
        ),
      ),
    );
    final text = tester.getRect(find.text('登录已失效，点此重新登录'));
    final target = tester.getRect(find.byType(InkWell));
    expect(target.height, greaterThanOrEqualTo(text.height + 16));
    expect(target.height, greaterThanOrEqualTo(48));
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);
    expect(tester.takeException(), isNull);
    state.value = SessionState.restoring;
    await tester.pump();
    expect(find.text('正在登录…'), findsOneWidget);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    state.value = SessionState.loggedIn;
    await tester.pump();
    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('三个格子都在，金额按两位小数写，未读按「N 封」写', (tester) async {
    await _pump(
      tester,
      const AccountStatus(
        ecardBalance: '23.5',
        netBalance: '0.00',
        unreadMail: 3,
      ),
    );

    expect(find.text('未读邮件'), findsOneWidget);
    expect(find.text('校园卡余额'), findsOneWidget);
    expect(find.text('校园网余额'), findsOneWidget);
    expect(find.text('3 封'), findsOneWidget);
    expect(find.text('¥23.50'), findsOneWidget);
    // 校园网 0 元：数字照给，另加一句提醒。
    expect(find.text('¥0.00'), findsOneWidget);
    expect(find.text('余额为 0，可能断网'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('没拿到状态时写「未知」，不编数字', (tester) async {
    await _pump(tester, null);
    expect(find.text('未知'), findsWidgets);
    expect(find.textContaining('¥'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('校园卡余额低于 20 元给充值提醒', (tester) async {
    await _pump(tester, const AccountStatus(ecardBalance: '12.3'));
    expect(find.text('低于 20 元，该充了'), findsOneWidget);
  });

  // 三个数字并排时，2 倍字号下每格只剩三十来像素，必须改竖排。
  testWidgets('2 倍字号下三个指标改成竖排且不溢出', (tester) async {
    await _pump(
      tester,
      const AccountStatus(
        ecardBalance: '1234.56',
        netBalance: '78.90',
        unreadMail: 12,
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    final mail = tester.getRect(find.text('未读邮件'));
    final card = tester.getRect(find.text('校园卡余额'));
    expect(card.top, greaterThan(mail.top), reason: '竖排时下面一行该在更下方');
  });
}
