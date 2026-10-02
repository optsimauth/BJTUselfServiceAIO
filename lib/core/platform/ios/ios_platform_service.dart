import '../method_channel_platform_service.dart';
import '../platform_service.dart';

class IosPlatformService extends MethodChannelPlatformService {
  IosPlatformService() : super(channelName: 'bjtuselfservice/ios');

  @override
  PlatformKind get kind => PlatformKind.ios;

  @override
  Future<void> refreshHomeWidget(Map<String, Object?> payload) async {
    // iOS 用 WidgetKit + App Group，细节在原生侧。
    await super.refreshHomeWidget(payload);
  }
}
