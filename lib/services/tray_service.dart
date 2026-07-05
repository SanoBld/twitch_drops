import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'log_service.dart';

class TrayService with TrayListener, WindowListener {
  // Not final: main.dart sets safe defaults at startup, then HomeScreen
  // rewires these to the real implementations once it's mounted (it's the
  // only place that has access to MiningService/CampaignService).
  void Function() onShowWindow;
  void Function() onQuit;
  void Function() onStopMining;
  void Function()? onToggleAutoMining;
  void Function()? onRefreshNow;

  final _log = LogService();

  String? _miningChannel;
  String? _miningGame;
  double? _miningProgress; // 0.0–1.0, current drop's progress
  bool _autoMiningEnabled = true;

  TrayService({
    required this.onShowWindow,
    required this.onQuit,
    required this.onStopMining,
    this.onToggleAutoMining,
    this.onRefreshNow,
  });

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      await trayManager.setIcon('assets/tray_icon.ico');
    } catch (e) {
      _log.log('setIcon failed: $e', tag: 'TrayService');
    }
    try {
      await trayManager.setToolTip('Twitch Drops Miner');
    } catch (e) {
      _log.log('setToolTip failed: $e', tag: 'TrayService');
    }
    await _rebuildMenu();
    _log.log('TrayService.init() completed', tag: 'TrayService');
  }

  // Call this whenever the mined channel changes so the tray menu reflects it.
  Future<void> updateMiningStatus(
    String? channelName, {
    String? gameName,
    double? progress,
  }) async {
    _miningChannel = channelName;
    _miningGame = gameName;
    _miningProgress = progress;
    await trayManager.setToolTip(
      channelName != null
          ? 'Twitch Drops Miner — Mining $channelName'
          : 'Twitch Drops Miner — Idle',
    );
    await _rebuildMenu();
  }

  Future<void> setAutoMiningState(bool enabled) async {
    _autoMiningEnabled = enabled;
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    try {
      final progressLabel = _miningProgress != null
          ? '${(_miningProgress! * 100).toStringAsFixed(0)}%'
          : null;

      final items = <MenuItem>[
        MenuItem(key: 'show', label: 'Show window'),
        MenuItem.separator(),
        if (_miningChannel != null) ...[
          MenuItem(
            key: 'status',
            label: '⚡ Mining: $_miningChannel'
                '${_miningGame != null ? ' ($_miningGame)' : ''}',
            disabled: true,
          ),
          if (progressLabel != null)
            MenuItem(
              key: 'progress',
              label: 'Current drop: $progressLabel',
              disabled: true,
            ),
          MenuItem(key: 'stop', label: 'Stop mining'),
        ] else
          MenuItem(key: 'status', label: 'Idle', disabled: true),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_auto',
          label: _autoMiningEnabled
              ? 'Disable auto-mining'
              : 'Enable auto-mining',
        ),
        MenuItem(key: 'refresh', label: 'Refresh campaigns now'),
        MenuItem(key: 'inventory', label: 'Open Twitch inventory'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ];
      await trayManager.setContextMenu(Menu(items: items));
      _log.log('Tray menu rebuilt successfully (${items.length} items)',
          tag: 'TrayService');
    } catch (e, st) {
      _log.log('_rebuildMenu FAILED: $e\n$st', tag: 'TrayService');
    }
  }

  @override
  void onTrayIconMouseDown() {
    // Left click only — show the window. Do NOT do this for right-click,
    // or it steals focus and dismisses the context menu before Windows
    // can display it (this was the real bug: every click, including
    // right-click, was triggering onShowWindow()).
    onShowWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Explicitly pop up the context menu on right-click instead of
    // relying on the OS to do it automatically — on Windows this is
    // what actually makes the menu appear reliably with tray_manager.
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'show':
        onShowWindow();
      case 'stop':
        onStopMining();
      case 'toggle_auto':
        onToggleAutoMining?.call();
      case 'refresh':
        onRefreshNow?.call();
      case 'inventory':
        launchUrl(Uri.parse('https://www.twitch.tv/drops/inventory'),
            mode: LaunchMode.externalApplication);
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