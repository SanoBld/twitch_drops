import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_theme/system_theme.dart';
import 'app.dart';
import 'services/tray_service.dart';
import 'services/autostart_service.dart';
import 'services/theme_settings.dart';

late TrayService trayService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Load the real Windows accent color before the first frame so the
  // theme is correct immediately (no flash of the fallback color).
  await SystemTheme.accentColor.load();
  await ThemeSettings().load();

  final windowOptions = WindowOptions(
    size: const Size(960, 660),
    minimumSize: const Size(720, 520),
    center: true,
    title: 'Twitch Drops Miner',
    // Hides the native OS title bar/border — app.dart draws its own
    // custom title bar (drag area + min/max/close) instead.
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // On some Windows setups, WindowOptions.titleBarStyle alone doesn't
    // fully suppress the native caption buttons — this call forces it,
    // which was causing a second, native gray titlebar to render above
    // our custom one.
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden,
        windowButtonVisibility: false);
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