import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/service_locator.dart';
import 'core/storage/preferences.dart';
import 'core/utils/log_recorder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');

  // 错误钩子必须比 runApp 早，否则启动期崩溃就丢了。日志目录设置在应用私有
  // 目录，用户可以在设置页换成自己选的位置。
  await LogRecorder.instance.install((await AppPreferences.open()).logDirectory);

  // release 模式下 build 失败默认是一片灰红方块，用户什么都看不懂。
  // 换成一句人话 + 出错的那段文字，截图报问题时也带得走信息。
  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFF1C1B1F),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '这个页面出了点问题\n\n${details.exceptionAsString()}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFE6E0E9), fontSize: 13),
        ),
      ),
    ),
  );

  // 自动登录放在 AppWidget 里跑：开屏不等网络，守卫先停在启动页。
  final locator = await ServiceLocator.bootstrap();
  runApp(BjtuSelfServiceApp(locator: locator));
}
