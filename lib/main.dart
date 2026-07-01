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
    size: Size(960, 660),
    minimumSize: Size(720, 520),
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
    onStopMining: () {
      // Handled by HomeScreen via stream; just show window so user sees it.
      windowManager.show();
    },
  );
  await trayService.init();
  await AutostartService().init();

  runApp(const App());
}
