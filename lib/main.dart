import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/logging/app_logger.dart';
import 'ui/app/novadl_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.configure(debugMode: true);

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1320, 840),
      minimumSize: Size(1120, 720),
      center: true,
      title: 'NovaDL',
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  doWhenWindowReady(() {
    appWindow.minSize = const Size(1120, 720);
  });

  runApp(const ProviderScope(child: NovaDLApp()));
}
