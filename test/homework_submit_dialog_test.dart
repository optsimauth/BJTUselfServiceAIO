import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bjtuselfserviceaio/core/state/sync_module.dart';
import 'package:bjtuselfserviceaio/core/state/sync_result.dart';
import 'package:bjtuselfserviceaio/data/models/homework/homework_model.dart';
import 'package:bjtuselfserviceaio/data/repositories/homework_repository.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_controller.dart';
import 'package:bjtuselfserviceaio/features/homework/homework_submit_dialog.dart';
import 'package:bjtuselfserviceaio/services/file_picker/file_picker_service.dart';
import 'package:bjtuselfserviceaio/shared/theme/app_theme.dart';

/// 交作业的入口曾经是「详情弹窗底部一个按钮，点了直接弹系统选文件」——
/// 用户既看不到选了哪些，也没法写备注。这里把该有的交互钉住。
const _homework = Homework(
  upId: 7,
  courseName: '大学物理',
  title: '第三次上机',
  content: '<p>周五前交</p>',
  endTime: '2026-11-01 23:59',
  subStatus: '未提交',
);

void main() {
  testWidgets('没选文件时提交按钮不可用，并说明原因', (tester) async {
    await _pump(tester, repository: _RecordingRepository());

    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '提交'),
    );
    expect(submit.onPressed, isNull);
    expect(find.text('先添加要交的文件，平台不接受空附件提交'), findsOneWidget);
  });

  testWidgets('选文件 → 写备注 → 提交：路径和正文都传到仓库', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository);

    await tester.tap(find.text('添加文件'));
    await tester.pumpAndSettle();
    expect(find.text('实验报告.pdf'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '迟交一天，抱歉');
    await tester.tap(find.widgetWithText(FilledButton, '提交'));
    await tester.pumpAndSettle();

    expect(repository.uploads.single.files, ['/tmp/实验报告.pdf']);
    expect(repository.uploads.single.content, '迟交一天，抱歉');
    // 交完就关弹窗，别让用户对着一个已经成功了的表单。
    expect(find.byType(HomeworkSubmitDialog), findsNothing);
  });

  testWidgets('移除已选文件后又回到「不能交」', (tester) async {
    await _pump(tester, repository: _RecordingRepository());

    await tester.tap(find.text('添加文件'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '提交'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byTooltip('移除'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '提交'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('上传失败：错误留在表单里，弹窗不关', (tester) async {
    final repository = _RecordingRepository(failWith: StateError('平台返回失败'));
    await _pump(tester, repository: repository);

    await tester.tap(find.text('添加文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '提交'));
    await tester.pumpAndSettle();

    expect(find.text('平台返回失败'), findsOneWidget);
    expect(find.byType(HomeworkSubmitDialog), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _RecordingRepository repository,
}) async {
  final controller = HomeworkController(repository: repository);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showHomeworkSubmitDialog(
                context,
                homework: _homework,
                controller: controller,
                pickFiles: () async => const [
                  PickedFileInfo(
                    name: '实验报告.pdf',
                    path: '/tmp/实验报告.pdf',
                    sizeBytes: 2048,
                  ),
                ],
              ),
              child: const Text('去提交'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('去提交'));
  await tester.pumpAndSettle();
}

class _RecordingRepository extends Fake implements HomeworkRepository {
  _RecordingRepository({this.failWith});

  /// 非空 = 提交时抛这个错，用来验失败态。
  final Object? failWith;

  final List<({List<String> files, String content})> uploads = [];

  @override
  Stream<List<Homework>> watchAll() => Stream<List<Homework>>.value(const []);

  @override
  Future<SyncResult> sync() async => const SyncResult(
    module: SyncModule.homework,
    added: 0,
    modified: 0,
    deleted: 0,
  );

  @override
  Future<String> upload(
    Homework homework, {
    required List<String> filePaths,
    String content = '',
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    uploads.add((files: filePaths, content: content));
    return '{"success":true}';
  }
}
