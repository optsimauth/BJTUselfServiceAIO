// Windows runner 没注册任何 MethodChannelHandler，openFile / notify 这些调用
// 以前会抛 MissingPluginException，变成刷屏的未捕获异步异常。
// 钉住「没实现 = 返回降级结果，不抛」。
import 'package:bjtuselfserviceaio/core/platform/method_channel_platform_service.dart';
import 'package:bjtuselfserviceaio/core/platform/platform_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoChannelService extends MethodChannelPlatformService {
  _NoChannelService() : super(channelName: 'bjtuselfservice/test-none');

  @override
  PlatformKind get kind => PlatformKind.windows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('通道没人实现时不抛，降级成 false / 空动作', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final service = _NoChannelService();

    try {
      await service.notify(title: 't', body: 'b');
      await service.refreshHomeWidget(const {});
      expect(await service.pickFiles(), isEmpty);
      // openFile / openUrl 有桌面兜底（explorer / cmd start），有值就行。
      expect(await service.openFile('C:\\tmp\\a.txt'), isA<bool>());
      expect(await service.openUrl('https://example.com'), isA<bool>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
