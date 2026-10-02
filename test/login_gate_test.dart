import 'package:bjtuselfserviceaio/app/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// 登录守卫：有凭据就放行进主页（登录在背后跑），没凭据才要手输。
void main() {
  String? guard({
    required bool hasCredentials,
    required bool loggedIn,
    String at = AppRoutes.home,
  }) => loginRedirect(
    hasCredentials: hasCredentials,
    isLoggedIn: loggedIn,
    location: at,
  );

  test('没凭据（第一次用）：一律送去登录页', () {
    expect(guard(hasCredentials: false, loggedIn: false), AppRoutes.login);
    expect(
      guard(hasCredentials: false, loggedIn: false, at: AppRoutes.grade),
      AppRoutes.login,
    );
    expect(
      guard(hasCredentials: false, loggedIn: false, at: AppRoutes.login),
      isNull,
    );
  });

  test('有凭据：自动登录成不成功都先让用户看本地数据', () {
    expect(guard(hasCredentials: true, loggedIn: false), isNull);
    expect(
      guard(hasCredentials: true, loggedIn: false, at: AppRoutes.grade),
      isNull,
    );
  });

  test('有凭据且已登录：手动登录成功后自己走出登录页', () {
    expect(
      guard(hasCredentials: true, loggedIn: true, at: AppRoutes.login),
      AppRoutes.home,
    );
    expect(guard(hasCredentials: true, loggedIn: true), isNull);
  });
}
