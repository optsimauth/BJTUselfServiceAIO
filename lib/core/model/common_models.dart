import 'package:flutter/foundation.dart';

/// 登录凭据。core 层认识它，所以 storage / event 不用反过来依赖 data 层。
@immutable
class Credentials {
  const Credentials({required this.username, required this.password});

  static const Credentials empty = Credentials(username: '', password: '');

  final String username;
  final String password;

  bool get isValid => username.trim().isNotEmpty && password.isNotEmpty;

  Credentials copyWith({String? username, String? password}) => Credentials(
    username: username ?? this.username,
    password: password ?? this.password,
  );

  @override
  bool operator ==(Object other) =>
      other is Credentials &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(username, password);

  @override
  String toString() => 'Credentials($username)';
}
