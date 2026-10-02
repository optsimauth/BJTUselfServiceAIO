import '../method_channel_platform_service.dart';
import '../platform_service.dart';

class WindowsPlatformService extends MethodChannelPlatformService {
  WindowsPlatformService() : super(channelName: 'bjtuselfservice/windows');

  @override
  PlatformKind get kind => PlatformKind.windows;
}
