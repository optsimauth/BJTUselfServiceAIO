// 作业详情弹窗的手机截图，给「改完自己看一眼」用。
//
// 跑法：`flutter test tool/ui_shot_homework_dialog.dart`，
// 输出到 `build/ui-review/homework-dialog-*.png`。
// 场景多的时候按名字单跑更稳（flutter_tester 连续 toImage 容易被环境杀）：
// `flutter test tool/ui_shot_homework_dialog.dart --plain-name submitted`。
//
// 和 tool/ui_shot_classroom.dart 一样不进 test/：没有断言，只出图。
// 注意 flutter_tester 里没有平台视图，正文走的是**纯文本降级**那一支；
// WebView 真正渲染成什么样得在真机 / 桌面窗口里看。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bjtuselfserviceaio/data/models/homework/homework_model.dart';
import 'package:bjtuselfserviceaio/data/repositories/homework_repository.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_controller.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_page.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// 一条场景 = 一张图。字段就是「这份作业长什么样」。
class _Scenario {
  const _Scenario({
    required this.name,
    required this.homework,
    this.dark = false,
    this.textScale = 1,
    this.repository,
  });

  final String name;
  final Homework homework;
  final bool dark;
  final double textScale;
  final HomeworkRepository? repository;
}

class _FakeHomeworkRepository extends Fake implements HomeworkRepository {
  @override
  Stream<List<Homework>> watchAll() => Stream<List<Homework>>.value(const []);

  @override
  Future<HomeworkDetail?> cachedDetail(Homework homework) async => null;

  @override
  Future<HomeworkDetail> fetchDetail(
    Homework homework, {
    bool allowCache = true,
  }) async => const HomeworkDetail(
    content:
        '<p>第三次上机：实现一个带缓存的 HTTP 客户端。</p>'
        '<p>1. 支持 GET / POST；<br>2. 命中缓存直接返回；<br>3. 写一份简单的测试。</p>'
        '<p>提交格式：PDF，命名「学号-姓名-第三次上机」。</p>',
    attachments: [
      HomeworkAttachment(id: 1, fileName: '第三次上机说明.pdf', sizeBytes: 482133),
      HomeworkAttachment(id: 2, fileName: '实验模板.docx', sizeBytes: 30512),
    ],
  );
}

/// 详情拉取失败：正文照旧（列表里那份 content），附件栏说明原因。
class _FailingHomeworkRepository extends Fake implements HomeworkRepository {
  @override
  Stream<List<Homework>> watchAll() => Stream<List<Homework>>.value(const []);

  @override
  Future<HomeworkDetail?> cachedDetail(Homework homework) async => null;

  @override
  Future<HomeworkDetail> fetchDetail(
    Homework homework, {
    bool allowCache = true,
  }) async => throw StateError('平台没有返回作业详情');
}

/// 详情里没有附件：附件栏走「暂无附件」空态。
class _EmptyAttachmentsHomeworkRepository extends Fake
    implements HomeworkRepository {
  @override
  Stream<List<Homework>> watchAll() => Stream<List<Homework>>.value(const []);

  @override
  Future<HomeworkDetail?> cachedDetail(Homework homework) async => null;

  @override
  Future<HomeworkDetail> fetchDetail(
    Homework homework, {
    bool allowCache = true,
  }) async => const HomeworkDetail(
    content: '<p>第三次上机：实现一个带缓存的 HTTP 客户端。</p>',
  );
}

const _pending = Homework(
  upId: 7,
  courseName: '计算机网络',
  title: '第三次上机：HTTP 客户端',
  content: '<p>请于周五前提交实验报告</p>',
  endTime: '2026-11-01 23:59',
  subStatus: '未提交',
);

/// 已交 + 已批改：头部状态徽章换一边，卡片行多一条分数。
const _submitted = Homework(
  upId: 7,
  courseName: '计算机网络',
  title: '第三次上机：HTTP 客户端',
  content: '<p>请于周五前提交实验报告</p>',
  endTime: '2026-11-01 23:59',
  subStatus: '已提交',
  score: '92',
  scoreId: 3,
);

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
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
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
    final loader = FontLoader('NotoSansSC')
      ..addFont(rootBundle.load('assets/fonts/NotoSansSC-VF.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  // 两个场景要挂假仓库实例，列表整体没法 const。
  final scenarios = <_Scenario>[
    _Scenario(name: 'homework-dialog-light', homework: _pending),
    _Scenario(name: 'homework-dialog-dark', homework: _pending, dark: true),
    _Scenario(
      name: 'homework-dialog-light-2x',
      homework: _pending,
      textScale: 2,
    ),
    _Scenario(name: 'homework-dialog-submitted-light', homework: _submitted),
    _Scenario(
      name: 'homework-dialog-empty-attachments-light',
      homework: _pending,
      repository: _EmptyAttachmentsHomeworkRepository(),
    ),
    _Scenario(
      name: 'homework-dialog-error-light',
      homework: _pending,
      repository: _FailingHomeworkRepository(),
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets(scenario.name, (tester) async {
      await _shootDialog(tester, scenario);
    });
  }
}

Future<void> _shootDialog(WidgetTester tester, _Scenario scenario) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final controller = HomeworkController(
    repository: scenario.repository ?? _FakeHomeworkRepository(),
  );
  addTearDown(controller.dispose);

  final key = GlobalKey();
  // 弹窗在 Overlay 里，边界要包住整个 MaterialApp，否则只截到底页；
  // 同理字号要从 builder 进 —— 那里包住 Navigator，弹窗才吃得到。
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: scenario.dark ? AppTheme.dark() : AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scenario.textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => openHomeworkDetail(
                  context,
                  controller,
                  scenario.homework,
                  DateTime(2026, 10, 25, 9),
                ),
                child: const Text('打开作业'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开作业'));
  await tester.pumpAndSettle();
  await _shot(tester, key, scenario.name);
}
