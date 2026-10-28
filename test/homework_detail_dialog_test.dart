import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/data/models/homework/homework_model.dart';
import 'package:bjtuselfserviceaio/data/repositories/homework_repository.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_controller.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_html_view.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_page.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';

/// 作业详情：点卡片 → dialog → 正文按 HTML 渲染（旧项目 HomeworkDetailDialog）。
///
/// 这里能验的只有「结构与文档」这两层：flutter_tester 没有平台视图，
/// [HomeworkHtmlView] 会走纯文本降级（这本身也是一条要保证的路径）。
/// 真正的 WebView 渲染得在真机 / 桌面窗口里看。
void main() {
  group('作业正文 HTML 文档', () {
    test('正文原样进去，主题色与字号写进 CSS', () {
      final scheme = AppTheme.dark().colorScheme;
      final html = buildHomeworkHtml(
        '<p>周五前交实验报告</p>',
        scheme: scheme,
        background: scheme.surfaceContainerHigh,
        fontSize: 24,
      );

      expect(html, contains('<p>周五前交实验报告</p>'));
      // 深色模式下字色必须是浅的：写死黑色就是「深底黑字」。
      expect(html, contains(_css(scheme.onSurface)));
      expect(html, contains(_css(scheme.surfaceContainerHigh)));
      expect(html, contains('font-size: 24.0px'));
      // 表格不撑破弹窗。
      expect(html, contains('max-width: 100%'));
    });

    test('纯文本正文换上行，不被当成 HTML', () {
      final scheme = AppTheme.light().colorScheme;
      final html = buildHomeworkHtml(
        '第一行\n第二行 <不是标签>',
        scheme: scheme,
        background: scheme.surface,
        fontSize: 16,
      );

      expect(html, contains('white-space: pre-wrap'));
      expect(html, contains('第一行\n第二行'));
      // 正文里的尖括号得转义，否则会被当成标签吃掉。
      expect(html, contains('&lt;不是标签&gt;'));
    });

    test('正文为空时给旧项目同一句占位', () {
      final scheme = AppTheme.light().colorScheme;
      final html = buildHomeworkHtml(
        '   ',
        scheme: scheme,
        background: scheme.surface,
        fontSize: 16,
      );
      expect(html, contains(homeworkEmptyContentHint));
    });
  });

  group('纯文本降级', () {
    test('剥标签但保住段落换行', () {
      expect(htmlToPlainText('<p>第一段</p><p>第二段<br>换行</p>'), '第一段\n第二段\n换行');
    });

    test('本来就是纯文本的原样返回', () {
      expect(htmlToPlainText(' 没有标签的正文 '), '没有标签的正文');
    });

    test('空正文返回空串，界面自己决定占位文案', () {
      expect(htmlToPlainText('   '), isEmpty);
    });
  });

  group('作业详情弹窗', () {
    testWidgets('点开是 dialog，正文渲染出来，关闭能收起', (tester) async {
      await _pumpLauncher(tester);
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('第三次上机'), findsOneWidget);
      expect(find.text('大学物理'), findsOneWidget);
      expect(find.text('作业内容'), findsOneWidget);
      // 没有平台视图时走纯文本降级，标签要已经被剥掉。
      expect(find.text('请于周五前提交实验报告'), findsOneWidget);
      expect(find.textContaining('<p>'), findsNothing);
      // 提交状态：平台没给 subStatus，按已交/没交兜底。
      expect(find.text('未提交'), findsOneWidget);
      expect(find.text('附件'), findsOneWidget);
      expect(find.text('暂无附件'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('取详情失败：正文照常显示，附件栏说明原因', (tester) async {
      await _pumpLauncher(tester, repository: _FailingHomeworkRepository());
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      // 列表里那份 content 是先拿到了的，不能因为详情失败就整篇消失
      // （旧项目 HomeworkDetailDialog 也是正文照放、错误放附件栏）。
      expect(find.text('请于周五前提交实验报告'), findsOneWidget);
      expect(find.textContaining('附件加载失败'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('窄屏 + 2 倍字号：弹窗不溢出', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpLauncher(tester, textScale: 2);
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 弹窗不许超出窗口（两边留白由 insetPadding 兜着）。
      final rect = tester.getRect(find.byType(Dialog));
      expect(rect.width, lessThanOrEqualTo(360));
      expect(rect.height, lessThanOrEqualTo(640));
    });
  });

  group('作业列表卡片', () {
    testWidgets('每张卡片都带已提交 / 未提交', (tester) async {
      final controller = HomeworkController(repository: _FakeHomeworkRepository());
      addTearDown(controller.dispose);
      await controller.hydrate();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: HomeworkPage(controller: controller, now: DateTime(2026, 10, 25, 9)),
        ),
      );
      await tester.pumpAndSettle();

      // 只看卡片本身：分组标题（「待提交 / 已提交 / 已批改」）和汇总卡
      // 也带这些字样，整页 find 会把它们混进来。
      final cards = find.byType(Card);
      expect(cards, findsNWidgets(2));
      // 状态跟着 subStatus 走，一条都不能少。
      expect(find.descendant(of: cards, matching: find.text('未提交')), findsOneWidget);
      expect(find.descendant(of: cards, matching: find.text('已提交')), findsOneWidget);
      // 旧项目卡片上的批改状态这一行也补上了。
      expect(find.descendant(of: cards, matching: find.text('未批改')), findsOneWidget);
      expect(find.descendant(of: cards, matching: find.text('已批改')), findsOneWidget);
      // 时间项照旧项目 InfoItem：开放主行 + 截止次行。
      expect(
        find.descendant(of: cards, matching: find.text('开放 2026-10-20 08:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cards, matching: find.text('截止 2026-11-01 23:59')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpLauncher(
  WidgetTester tester, {
  double textScale = 1,
  HomeworkRepository? repository,
}) async {
  final controller = HomeworkController(
    repository: repository ?? _FakeHomeworkRepository(),
  );
  addTearDown(controller.dispose);
  final homework = const Homework(
    upId: 7,
    courseName: '大学物理',
    title: '第三次上机',
    content: '<p>请于周五前提交实验报告</p>',
    endTime: '2026-11-01 23:59',
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      // 字号必须从 MaterialApp.builder 进 —— 那一层包住 Navigator，
      // 弹窗（在 Overlay 里）才吃得到；放进 home 或者自己新建一份
      // MediaQueryData 都不行：前者盖不到弹窗，后者会把窗口尺寸清成 0。
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => openHomeworkDetail(
                context,
                controller,
                homework,
                DateTime(2026, 10, 25, 9),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
}

String _css(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

class _FakeHomeworkRepository extends Fake implements HomeworkRepository {
  @override
  Stream<List<Homework>> watchAll() => Stream<List<Homework>>.value([
    Homework(
      upId: 7,
      courseName: '大学物理',
      title: '第三次上机',
      content: '<p>请于周五前提交实验报告</p>',
      endTime: '2026-11-01 23:59',
      openDate: '2026-10-20 08:00',
      subStatus: '未提交',
      submitCount: 12,
      allCount: 40,
    ),
    Homework(
      upId: 8,
      courseName: '高等数学',
      title: '第二次作业',
      content: '<p>已完成</p>',
      endTime: '2026-10-20 23:59',
      subStatus: '已提交',
      score: '92',
      scoreId: 3,
    ),
  ]);

  @override
  Future<HomeworkDetail> fetchDetail(Homework homework) async =>
      const HomeworkDetail(content: '<p>请于周五前提交实验报告</p>');
}

class _FailingHomeworkRepository extends Fake implements HomeworkRepository {
  @override
  Stream<List<Homework>> watchAll() => Stream<List<Homework>>.value(const []);

  @override
  Future<HomeworkDetail> fetchDetail(Homework homework) async =>
      throw StateError('平台没有返回作业详情');
}
