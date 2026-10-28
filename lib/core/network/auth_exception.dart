class SsoLoginException implements Exception {
  const SsoLoginException(this.message);
  final String message;
  @override
  String toString() => message;
}
