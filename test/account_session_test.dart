import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bjtuselfserviceaio/core/database/database.dart';
import 'package:bjtuselfserviceaio/core/model/common_models.dart';
import 'package:bjtuselfserviceaio/core/network/auth_exception.dart';
import 'package:bjtuselfserviceaio/core/network/cookie_manager.dart';
import 'package:bjtuselfserviceaio/core/network/request_manager.dart';
import 'package:bjtuselfserviceaio/core/storage/preferences.dart';
import 'package:bjtuselfserviceaio/core/storage/secure_storage.dart';
import 'package:bjtuselfserviceaio/data/models/grade/grade_model.dart';
import 'package:bjtuselfserviceaio/data/remote/api/auth_api.dart';
import 'package:bjtuselfserviceaio/data/repositories/account_repository.dart';
import 'package:bjtuselfserviceaio/data/repositories/grade_repository.dart';
import 'package:bjtuselfserviceaio/features/grade/grade_controller.dart';

class _Auth extends AuthApi {
  _Auth() : super(RequestManager(dio: Dio(), ensureLoggedIn: () {}));
  Future<void> Function()? authenticate;
  @override
  Future<void> login(Credentials credentials) async => authenticate?.call();
  @override
  Future<String> initializeCoursePlatform() async => '';
  @override
  Future<String> aaLogin() async => '';
  @override
  Future<String> bksyLogin() async => '';
}

class _Grades extends Fake implements GradeRepository {
  final requestedIds = <String>[];
  @override
  Stream<List<Grade>> watchAll() => const Stream.empty();
  @override
  List<GradeSelectionRecord> loadSelections(String id) {
    requestedIds.add(id);
    return id == 'student-a'
        ? const [GradeSelectionRecord(courseName: '高等数学')]
        : [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late AppPreferences prefs;
  late SecureStorage storage;
  late _Auth api;
  late AccountRepository account;
  var cleared = 0;
  const credentials = Credentials(
    username: 'test-student',
    password: 'temporary-password',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    prefs = await AppPreferences.open();
    storage = SecureStorage();
    await storage.readCredentials();
    api = _Auth();
    cleared = 0;
    account = AccountRepository(
      api: api,
      cookieManager: AppCookieManager(),
      secureStorage: storage,
      preferences: prefs,
      database: db,
      onSessionCleared: () => cleared++,
    );
  });
  tearDown(() async {
    account.dispose();
    prefs.dispose();
    await db.close();
  });

  test('首次成功登录才保存凭据，登录门闸与 ready 同步完成', () async {
    expect(account.hasCredentials, isFalse);
    await account.login(credentials);
    await account.whenSessionReady;
    expect(account.isLoggedIn, isTrue);
    expect(storage.cachedCredentials!.username, 'test-student');
    expect(account.requireLogin, returnsNormally);
  });

  test('失败不保存密码，自动恢复失败仍完成 ready 并保留离线凭据', () async {
    api.authenticate = () async => throw const SsoLoginException('密码错误');
    await expectLater(
      account.login(credentials),
      throwsA(isA<SsoLoginException>()),
    );
    expect(account.hasCredentials, isFalse);
    await storage.writeCredentials(credentials);
    await account.restoreSession();
    await account.whenSessionReady;
    expect(account.hasCredentials, isTrue);
    expect(account.isLoggedIn, isFalse);
  });

  test('登录未完成时退出，迟到的认证不得恢复登录和凭据', () async {
    final response = Completer<void>();
    api.authenticate = () => response.future;
    final login = account.login(credentials);
    final rejected = expectLater(login, throwsStateError);
    final logout = account.logout();
    response.complete();
    await rejected;
    await logout;
    expect(account.isLoggedIn, isFalse);
    expect(account.hasCredentials, isFalse);
    expect(cleared, 1);
  });

  test('拒绝并发登录，避免两份动态 OAuth 状态互相覆盖', () async {
    final response = Completer<void>();
    api.authenticate = () => response.future;
    final first = account.login(credentials);
    await expectLater(account.login(credentials), throwsStateError);
    response.complete();
    await first;
    expect(account.isLoggedIn, isTrue);
  });

  test('共享成绩控制器跟随首次登录与账号切换，退出清除选择', () {
    final repository = _Grades();
    final controller = GradeController(repository: repository);
    addTearDown(controller.dispose);
    expect(controller.hasStudent, isFalse);
    controller.updateStudentId('student-a');
    expect(controller.hasStudent, isTrue);
    expect(controller.selectedCount, 1);
    controller.updateStudentId('student-b');
    expect(controller.selectedCount, 0);
    controller.updateStudentId('');
    expect(controller.hasStudent, isFalse);
    expect(repository.requestedIds, ['student-a', 'student-b']);
  });

  test('旧账号的业务响应晚于新账号登录时返回，也不能送到仓库', () async {
    final request = RequestManager(dio: Dio(), ensureLoggedIn: () {});
    final response = Completer<String>();
    final pending = request.request(() => response.future);
    request.invalidateSession();
    final assertion = expectLater(pending, throwsA(isA<Exception>()));
    response.complete('old-account-data');
    await assertion;
    request.dio.close();
  });
}
