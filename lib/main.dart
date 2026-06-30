import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'services/tray_service.dart';
import 'services/autostart_service.dart';

late TrayService trayService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(900, 650),
    minimumSize: Size(700, 500),
    center: true,
    title: 'Twitch Drops Miner',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  trayService = TrayService(
    onShowWindow: () async {
      await windowManager.show();
      await windowManager.focus();
    },
    onQuit: () async {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    },
  );
  await trayService.init();
  await AutostartService().init();

  runApp(const App());
}
