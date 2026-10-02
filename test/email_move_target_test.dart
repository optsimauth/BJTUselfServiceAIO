// 「移到待办邮件」会拿到 FA_FOLDER_NOT_FOUND：待办邮件不是真文件夹，
// 它是每封邮件的 defer 标记出来的虚拟队列，服务端没有对应 fid。
// 这两条钉住「不发这种请求」。
import 'package:bjtuselfserviceaio/data/remote/api/email_api.dart';
import 'package:bjtuselfserviceaio/features/email/email_controller.dart';
import 'package:bjtuselfserviceaio/features/email/email_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEmailApi implements EmailApi {
  final moves = <({List<String> ids, int folderId})>[];

  @override
  Future<void> moveMessages(List<String> ids, int folderId) async =>
      moves.add((ids: ids, folderId: folderId));

  @override
  Future<MailboxPageResult> listMessages({
    required int folderId,
    int start = 0,
    int limit = 20,
  }) async => const MailboxPageResult(totalCount: 0, messages: []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('待办邮件和分组标题都不是可移动的目标', () {
    expect(
      defaultMailFolders
          .where((folder) => folder.isMovableTarget)
          .map((f) => f.id),
      isNot(contains(todoFolderId)),
      reason: '待办邮件是 defer 虚拟队列，往里移动服务端必回 FA_FOLDER_NOT_FOUND',
    );
    expect(
      defaultMailFolders.firstWhere((f) => f.isGroup).isMovableTarget,
      isFalse,
      reason: '分组标题没有 fid',
    );
  });

  test('移动菜单里只出现真文件夹', () {
    expect(
      moveTargetFolders.where((folder) => !folder.isMovableTarget),
      isEmpty,
    );
  });

  test('在待办邮件视图里移动：请求根本不发出去', () async {
    final api = _FakeEmailApi();
    final controller = EmailController(api: api);
    await controller.selectFolder(todoFolderId);

    expect(await controller.moveMessage('m1', 1), isFalse);
    expect(await controller.moveSelection(1), isFalse);
    expect(api.moves, isEmpty, reason: '发了服务端一定会拒的请求');
  });

  test('正常文件夹之间的移动照旧发请求', () async {
    final api = _FakeEmailApi();
    final controller = EmailController(api: api);

    expect(await controller.moveMessage('m1', 4), isTrue);
    expect(api.moves.single.folderId, trashFolderId);
  });
}
