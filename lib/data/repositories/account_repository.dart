import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/database/database.dart';
import '../../core/model/common_models.dart';
import '../../core/network/cookie_manager.dart';
import '../../core/network/network_exception.dart';
import '../../core/storage/preferences.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/logger.dart';
import '../../services/captcha/captcha_service.dart';
import '../models/account/account_model.dart';
import '../remote/api/auth_api.dart';
import '../remote/parsers/auth_parser.dart';

/// 会话状态。只有三个，够用。
enum SessionState {
  /// 冷启动后台正在静默登录：本地数据照常显示，顶部一条细进度条。
  restoring,

  /// 已登录，可以发业务请求、可以同步。
  loggedIn,

  /// 没登录（自动登录失败 / 用户退出）：本地旧数据继续可读。
  loggedOut,
}

/// 登录 / 登出 / 学生信息。整个 APP 唯一的登录入口，也是登录态的唯一持有者。
///
/// 登录只有一条路：CAS 登录页 -> 本地模型识别算式 -> 直接提交，界面不展示验证码。
/// 第一次由用户手输账号密码；之后每次冷启动都用存下来的凭据静默走同一条路
/// （[restoreSession]）：成功直接进主页，失败就退回登录页等用户手输。
class AccountRepository {
  AccountRepository({
    required AuthApi api,
    required CaptchaService captcha,
    required AppCookieManager cookieManager,
    required SecureStorage secureStorage,
    required AppPreferences preferences,
    required AppDatabase database,
    this.onSessionCleared,
  }) : _api = api,
       _captcha = captcha,
       _cookieManager = cookieManager,
       _secureStorage = secureStorage,
       _preferences = preferences,
       _database = database;

  static const Logger _log = Logger('AccountRepository');

  /// 登录态失效时清掉内存缓存。
  ///
  /// 数据库和 Cookie 能自己清干净，但课程平台会话 / 课程清单这类
  /// **内存缓存**看不到数据库清空，得靠这个回调通知一声，
  /// 否则登出再登录会一直用上一个账号的 sessionid 和课程列表。
  final VoidCallback? onSessionCleared;

  /// CAS 每次刷新登录页都会作废旧的 captcha key，识别错了就整体重来一次。
  static const int maxLoginAttempts = 2;

  final AuthApi _api;
  final CaptchaService _captcha;
  final AppCookieManager _cookieManager;
  final SecureStorage _secureStorage;
  final AppPreferences _preferences;
  final AppDatabase _database;

  final ValueNotifier<SessionState> _session = ValueNotifier(
    SessionState.restoring,
  );

  /// 无论登录成功还是失败，restoreSession 一结束就完成。
  /// 后台同步等它（这样第一轮同步不会打在未登录的半截上），
  /// 业务请求不等它（没登录就立刻失败，不排队）。
  final Completer<void> _ready = Completer<void>();

  bool get isLoggedIn => _session.value == SessionState.loggedIn;

  /// 界面跟着它重建：登录中的细进度条 / 登录失效的灰条。
  ValueListenable<SessionState> get sessionState => _session;

  Future<void> get whenSessionReady => _ready.future;

  /// 本地存着凭据吗？路由守卫只看这一件事：有就放行进主页，登录在背后跑。
  bool get hasCredentials => _secureStorage.cachedCredentials?.isValid ?? false;

  /// 业务请求的统一门闸，RequestManager 每条请求执行前都调它。
  ///
  /// 没登录就立刻失败，不排队等登录：排队只会让调用方的进度圈永远转下去。
  void requireLogin() {
    if (!isLoggedIn) {
      throw const NetworkException(NetworkErrorKind.unauthorized, '尚未登录');
    }
  }

  /// 冷启动：用本地凭据静默登录。没有凭据就什么都不做。
  ///
  /// 失败也不抛、不跳登录页、不清本地数据——界面自己会显示一条灰条。
  Future<void> restoreSession() async {
    try {
      final credentials = _secureStorage.cachedCredentials ?? Credentials.empty;
      if (credentials.isValid) {
        _log.d('用本地凭据自动登录：${credentials.username}');
        await login(credentials);
      }
    } catch (error) {
      _log.w('自动登录失败，本地数据继续可用', error);
    } finally {
      _mark(isLoggedIn ? SessionState.loggedIn : SessionState.loggedOut);
    }
  }

  /// 登录。失败直接抛异常，由登录页自己显示。
  Future<void> login(Credentials credentials) async {
    if (!credentials.isValid) {
      throw const FormatException('学号或密码为空');
    }
    Object? lastError;
    for (var attempt = 1; attempt <= maxLoginAttempts; attempt++) {
      try {
        await _loginOnce(credentials, attempt: attempt);
        await _secureStorage.writeCredentials(credentials);
        _mark(SessionState.loggedIn);
        return;
      } catch (error) {
        lastError = error;
        _log.w('第 $attempt 次登录失败', error);
      }
    }
    throw lastError ?? StateError('登录失败');
  }

  Future<void> logout() async {
    await _cookieManager.clear();
    await _secureStorage.clearCredentials();
    await _preferences.clearAllBusinessData();
    await _database.clearBusinessData();
    onSessionCleared?.call();
    _mark(SessionState.loggedOut);
  }

  Future<StudentProfile> fetchStudentProfile() async {
    final credentials = await _secureStorage.readCredentials();
    final raw = await _api.fetchSsoPage();
    return AuthParser.parseStudentProfile(raw, studentId: credentials.username);
  }

  /// 落一个终态，顺手把等待登录的队列放行。
  void _mark(SessionState state) {
    _session.value = state;
    if (!_ready.isCompleted) {
      _ready.complete();
    }
  }

  /// 单轮登录：已经登录过就直接返回，否则识别验证码并提交。
  Future<void> _loginOnce(
    Credentials credentials, {
    required int attempt,
  }) async {
    final ssoPage = await _api.fetchSsoPage();
    if (AuthParser.isAuthenticated(ssoPage)) {
      _log.d('会话仍有效，补齐子系统登录');
      await _loginSecondarySystems();
      return;
    }

    final fields = AuthParser.parseLoginFields(ssoPage);
    if (fields == null) {
      throw const CaptchaException('CAS 登录页缺少验证码字段');
    }

    final answer = await _solveCaptcha(fields.captchaKey);
    final response = await _api.submitCasLogin({
      'csrfmiddlewaretoken': fields.csrf,
      'captcha_0': fields.captchaKey,
      'captcha_1': answer,
      'loginname': credentials.username,
      'password': credentials.password,
      if (fields.next != null) 'next': fields.next!,
    }, referer: ApiConstants.casLoginPath);

    if (!AuthParser.isAuthenticated(response)) {
      throw CaptchaException('账号、密码或验证码错误（第 $attempt 次）');
    }
    await _loginSecondarySystems();
  }

  /// 下载验证码图片并本地识别，返回算式答案。
  Future<String> _solveCaptcha(String captchaKey) async {
    final bytes = await _api.fetchCaptchaImage(captchaKey: captchaKey);
    final expression = await _captcha.recognizeExpression(
      Uint8List.fromList(bytes),
    );
    final answer = _captcha.solve(expression);
    if (answer == null || answer.isEmpty) {
      throw CaptchaException('验证码算式解析失败：$expression');
    }
    return answer;
  }

  /// 建立课程平台、教务和本科生院的跨站会话。
  Future<void> _loginSecondarySystems() async {
    try {
      await _api.initializeCoursePlatform();
    } catch (error) {
      _log.w('课程平台登录失败，继续尝试其他系统', error);
    }
    for (final openSession in [_api.aaLogin, _api.bksyLogin]) {
      try {
        await openSession();
      } catch (error) {
        _log.w('附属系统登录失败，忽略', error);
      }
    }
  }
}
