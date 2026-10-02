import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bjtuselfserviceaio/core/network/request_manager.dart';
import 'package:bjtuselfserviceaio/core/platform/platform_service.dart';
import 'package:bjtuselfserviceaio/core/storage/preferences.dart';
import 'package:bjtuselfserviceaio/services/download/download_service.dart';

/// 只关心「落盘目录」的平台假实现：把字节写进临时目录，记录收到的目录。
class _FakePlatform implements PlatformService {
  _FakePlatform(this.root);

  final Directory root;
  final List<String?> savedDirectories = [];

  @override
  Future<Directory> downloadsDirectory() async => root;

  @override
  Future<String?> saveToDownloads({
    required String fileName,
    required List<int> bytes,
    String? directory,
    String? mimeType,
  }) async {
    savedDirectories.add(directory);
    final target = Directory(directory ?? root.path);
    await target.create(recursive: true);
    final file = File(p.join(target.path, fileName));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('dl_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<DownloadService> service({String? chosen}) async {
    final preferences = await AppPreferences.open();
    if (chosen != null) await preferences.setDownloadDirectory(chosen);
    return DownloadService(
      // 这几个用例只碰落盘目录，不发请求，所以给一个裸的 RequestManager。
      request: RequestManager(dio: Dio(), ensureLoggedIn: () {}),
      platform: _FakePlatform(temp),
      preferences: preferences,
    );
  }

  test('没设下载位置时：落在 系统下载目录/bjtuselfserviceaio/', () async {
    final downloads = await service();
    final path = await downloads.saveBytes(fileName: '中文成绩单.pdf', bytes: [1]);
    expect(path, p.join(temp.path, 'bjtuselfserviceaio', '中文成绩单.pdf'));
  });

  test('设了下载位置时：那一层在最外面', () async {
    final chosen = '${temp.path}/我的下载';
    final downloads = await service(chosen: chosen);
    final path = await downloads.saveBytes(fileName: '校历.pdf', bytes: [1]);
    expect(path, p.join(chosen, 'bjtuselfserviceaio', '校历.pdf'));
  });

  test('课件的课程目录排在 app 文件夹之后', () async {
    final chosen = '${temp.path}/我的下载';
    final downloads = await service(chosen: chosen);
    final directory = await downloads.targetDirectory(['高等数学', '第1章']);
    expect(directory, p.join(chosen, 'bjtuselfserviceaio', '高等数学', '第1章'));
  });
}
