import '../core/constants/api_constants.dart';

/// 编译期/启动期配置。旧项目这些常量散在 BuildConfig 和各自单例里。
class AppConfig {
  const AppConfig({
    this.apiBaseUrl = ApiConstants.misHost,
    this.enableCaptchaRecognition = true,
    this.enableHomeWidget = true,
    this.enableAutoUpdateCheck = true,
    this.verboseLogging = false,
  });

  /// 不注入任何依赖的默认配置，方便测试和桩页面直接 new。
  static const AppConfig defaults = AppConfig();

  final String apiBaseUrl;

  /// 验证码识别要加载模型，桌面端暂时没有推理实现。
  final bool enableCaptchaRecognition;

  final bool enableHomeWidget;
  final bool enableAutoUpdateCheck;
  final bool verboseLogging;
}
