// ignore_for_file: avoid_print
//
// 真实网络集成测试：验证码识别 -> CAS 登录 -> 只读业务接口。
//
// 运行：
//   $env:BJTU_USERNAME = '学号'
//   $env:BJTU_PASSWORD = '密码'
//   $env:BJTU_BUILDING = '教学楼名称' # 可选，启用空教室接口测试
//   flutter test test/network_test.dart --no-pub
//
// 不把真实账号密码写入测试文件；未设置账号时，这组测试会跳过。

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bjtuselfserviceaio/app/service_locator.dart';
import 'package:bjtuselfserviceaio/core/model/common_models.dart';
import 'package:bjtuselfserviceaio/data/models/classroom/classroom_model.dart';
import 'package:bjtuselfserviceaio/data/repositories/sync_coordinator.dart';

const Duration _testTimeout = Duration(minutes: 8);
const Duration _setupTimeout = Duration(minutes: 2);

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

Directory? _testStorageRoot;

Future<void> _installPathProviderMock() async {
  final root = await Directory.systemTemp.createTemp(
    'bjtuselfserviceaio_test_',
  );
  _testStorageRoot = root;
  final paths = <String, String>{
    'temporary': '${root.path}/temporary',
    'support': '${root.path}/support',
    'documents': '${root.path}/documents',
  };
  for (final path in paths.values) {
    await Directory(path).create(recursive: true);
  }

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, (call) async {
        return paths[switch (call.method) {
          'getTemporaryDirectory' => 'temporary',
          'getApplicationSupportDirectory' => 'support',
          'getApplicationDocumentsDirectory' => 'documents',
          _ => throw MissingPluginException(
            '未模拟 path_provider 方法: ${call.method}',
          ),
        }];
      });
}

Future<void> _removePathProviderMock() async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, null);
  final root = _testStorageRoot;
  _testStorageRoot = null;
  await root?.delete(recursive: true);
}

final String _username = Platform.environment['BJTU_USERNAME'] ?? '';
final String _password = Platform.environment['BJTU_PASSWORD'] ?? '';
final String _building = Platform.environment['BJTU_BUILDING'] ?? '';

String? get _networkSkipReason {
  if (_username.isEmpty || _password.isEmpty) {
    return '设置 BJTU_USERNAME 和 BJTU_PASSWORD 后再运行真实网络测试';
  }
  return null;
}

String? get _classroomSkipReason =>
    _building.isEmpty ? '设置 BJTU_BUILDING 后测试空教室接口' : null;

Future<ServiceLocator> _bootstrapAndLogin() async {
  await _installPathProviderMock();
  ServiceLocator? created;
  try {
    created = await ServiceLocator.bootstrap();
    await created.accountRepository.login(
      Credentials(username: _username, password: _password),
    );
    print('登录成功：${created.accountRepository.isLoggedIn}');
    return created;
  } catch (_) {
    await created?.dispose();
    await _removePathProviderMock();
    rethrow;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});

  ServiceLocator? locator;

  setUpAll(() async {
    if (_networkSkipReason != null) return;

    locator = await _bootstrapAndLogin().timeout(
      _setupTimeout,
      onTimeout: () => throw TimeoutException(
        '登录初始化超过 ${_setupTimeout.inMinutes} 分钟，请检查网络、账号或 CAS 服务',
      ),
    );
  });

  tearDownAll(() async {
    await locator?.dispose();
    await _removePathProviderMock();
  });

  test(
    '账户资料接口',
    () async {
      final profile = await locator!.accountRepository.fetchStudentProfile();
      print(
        '账户：${profile.studentId} ${profile.name} ${profile.college} ${profile.major}',
      );
      expect(profile.studentId, isNotEmpty);
    },
    skip: _networkSkipReason,
    timeout: const Timeout(_testTimeout),
  );

  test(
    '课表接口',
    () async {
      await locator!.syncCoordinator.syncModule(SyncModule.course);
      final courses = await locator!.courseRepository.watchAll().first;
      print('课表：${courses.length} 条');
      expect(courses, isA<List>());
    },
    skip: _networkSkipReason,
    timeout: const Timeout(_testTimeout),
  );

  test(
    '当前教学周接口',
    () async {
      final week = await locator!.courseRepository.refreshCurrentWeek();
      print('当前教学周：第 $week 周');
      expect(week, greaterThanOrEqualTo(0));
    },
    skip: _networkSkipReason,
    timeout: const Timeout(_testTimeout),
  );

  test(
    '成绩接口',
    () async {
      await locator!.syncCoordinator.syncModule(SyncModule.grade);
      final grades = await locator!.gradeRepository.watchAll().first;
      print('成绩：${grades.length} 条');
      expect(grades, isA<List>());
    },
    skip: _networkSkipReason,
    timeout: const Timeout(_testTimeout),
  );

  test(
    '考试安排接口',
    () async {
      await locator!.syncCoordinator.syncModule(SyncModule.exam);
      final exams = await locator!.examRepository.watchAll().first;
      print('考试安排：${exams.length} 条');
      expect(exams, isA<List>());
    },
    skip: _networkSkipReason,
    timeout: const Timeout(_testTimeout),
  );

  test(
    '课程平台课程接口',
    () async {
      final courses = await locator!.platformCourseRepository.currentCourses();
      print('课程平台课程：${courses.length} 条');
      expect(courses, isNotEmpty);
    },
    skip: _networkSkipReason,
    timeout: const Timeout(_testTimeout),
  );

  test(
    '作业接口',
    () async {
      await locator!.syncCoordinator.syncModule(SyncModule.homework);
      final homework = await locator!.homeworkRepository.watchAll().first;
      print('作业：${homework.length} 条');
      expect(homework, isA<List>());
    },
    skip: _networkSkipReason,
    timeout: const Timeout(_testTimeout),
  );

  test(
    '课件接口',
    () async {
      final tree = await locator!.coursewareRepository.refreshTree();
      print('课件课程根节点：${tree.length} 个');
      expect(tree, isNotEmpty);
    },
    skip: _networkSkipReason,
    timeout: const Timeout(_testTimeout),
  );

  test(
    '空教室接口',
    () async {
      final building = await locator!.classroomRepository.fetchBuilding(
        buildingName: _building,
      );
      final entry = await locator!.classroomRepository.openEntry();
      final target = ClassroomBuildings.byName(_building);
      final status = await locator!.classroomRepository.fetchWeekStatus(
        entryUri: entry.entryUri,
        week: entry.week,
        buildingId: (target ?? ClassroomBuildings.all.first).id,
      );
      print(
        '空教室：${building.classrooms.length} 间人数，'
        '状态周 ${status.week}，占用 ${status.rooms.length} 间',
      );
      expect(building.classrooms, isA<List>());
      expect(status.week, greaterThan(0));
      expect(status.rooms, isNotEmpty);
    },
    skip: _networkSkipReason ?? _classroomSkipReason,
    timeout: const Timeout(_testTimeout),
  );
}
