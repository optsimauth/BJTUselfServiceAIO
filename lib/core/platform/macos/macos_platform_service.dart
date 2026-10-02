import '../method_channel_platform_service.dart';
import '../platform_service.dart';

class MacosPlatformService extends MethodChannelPlatformService {
  MacosPlatformService() : super(channelName: 'bjtuselfservice/macos');

  @override
  PlatformKind get kind => PlatformKind.macos;
}
