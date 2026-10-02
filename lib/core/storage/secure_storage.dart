import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import '../model/common_models.dart';

/// 账号密码存储。旧版明文写在 DataStore 里，这里换成 Keychain / Keystore。
///
/// 额外做一个内存镜像：启动时预热一次，登录页就能**同步**拿到预填值。
/// 输入框的初值必须是同步的——异步回填会在用户已经动手改输入框之后才写进去，
/// 表现就是"删掉密码再输入，旧密码又粘回来"（曾经的 bug）。
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Credentials? _cached;

  /// 预热过之后的凭据；没预热过就是 null。
  Credentials? get cachedCredentials => _cached;

  Future<Credentials> readCredentials() async {
    final username = await _storage.read(key: StorageKeys.username) ?? '';
    final password = await _storage.read(key: StorageKeys.password) ?? '';
    final credentials = Credentials(username: username, password: password);
    _cached = credentials;
    return credentials;
  }

  Future<void> writeCredentials(Credentials credentials) async {
    await _storage.write(
      key: StorageKeys.username,
      value: credentials.username,
    );
    await _storage.write(
      key: StorageKeys.password,
      value: credentials.password,
    );
    _cached = credentials;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: StorageKeys.username);
    await _storage.delete(key: StorageKeys.password);
    _cached = Credentials.empty;
  }
}
