import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

// Handles minimize-to-tray behavior, similar to TDM running in the background.
class TrayService with TrayListener, WindowListener {
  final void Function() onShowWindow;
  final void Function() onQuit;

  TrayService({required this.onShowWindow, required this.onQuit});

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true); // intercept close button

    await trayManager.setIcon(
      // Windows needs .ico, Linux/macOS can use .png
      'assets/tray_icon.ico',
    );
    await trayManager.setToolTip('Twitch Drops Miner');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Show window'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
  }

  @override
  void onTrayIconMouseDown() {
    onShowWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') onShowWindow();
    if (menuItem.key == 'quit') onQuit();
  }

  // Instead of closing the app, hide it to tray and keep mining in background.
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }
}
