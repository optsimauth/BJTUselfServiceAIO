import 'dart:convert';

import 'package:gm_crypto/gm_crypto.dart';

import '../../core/network/auth_exception.dart';

/// 与学校 sm2.js 一致：C1C3C2 去掉 04 点前缀，再 Base64 编码。
abstract final class SsoPasswordCipher {
  static String encrypt(String password, String publicKey) {
    try {
      final key = base64Decode(publicKey);
      if (key.length != 65 || key.first != 4) {
        throw const FormatException('Invalid SM2 public key');
      }
      final encrypted = SM2.encrypt(password, toHex(key));
      return base64Encode(fromHex(encrypted.substring(2)));
    } catch (_) {
      throw const SsoLoginException('学校密码加密失败，请稍后重试');
    }
  }

  static String toHex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static List<int> fromHex(String hex) => [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}
