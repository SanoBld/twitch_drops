import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayService with TrayListener, WindowListener {
  final void Function() onShowWindow;
  final void Function() onQuit;
  final void Function() onStopMining;

  String? _miningChannel;

  TrayService({
    required this.onShowWindow,
    required this.onQuit,
    required this.onStopMining,
  });

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('Twitch Drops Miner');
    await _rebuildMenu();
  }

  // Call this whenever the mined channel changes so the tray menu reflects it.
  Future<void> updateMiningStatus(String? channelName) async {
    _miningChannel = channelName;
    await trayManager.setToolTip(
      channelName != null
          ? 'Twitch Drops Miner — Mining $channelName'
          : 'Twitch Drops Miner — Idle',
    );
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    final items = <MenuItem>[
      MenuItem(key: 'show', label: 'Show window'),
      MenuItem.separator(),
      if (_miningChannel != null) ...[
        MenuItem(
          key: 'status',
          label: '⚡ Mining: $_miningChannel',
          disabled: true,
        ),
        MenuItem(key: 'stop', label: 'Stop mining'),
      ] else
        MenuItem(key: 'status', label: 'Idle', disabled: true),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ];
    await trayManager.setContextMenu(Menu(items: items));
  }

  @override
  void onTrayIconMouseDown() => onShowWindow();

  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'show':
        onShowWindow();
      case 'stop':
        onStopMining();
      case 'quit':
        onQuit();
    }
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }
}
