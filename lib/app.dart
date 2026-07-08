import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'services/auth_service.dart';
import 'services/theme_settings.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AuthService _auth = AuthService();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _auth.load().then((_) => setState(() => _ready = true));
  }

  // Seed color: either the OS accent color or a user-picked custom color,
  // via ThemeSettings. Material 3 derives all other tones (secondary,
  // tertiary, containers, etc.) from this one seed automatically.
  Color get _seed => ThemeSettings().seed;

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.comfortable,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: _FadePageTransitionsBuilder(),
          TargetPlatform.linux: _FadePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadePageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the user changes the theme mode/color in Settings.
    return AnimatedBuilder(
      animation: ThemeSettings(),
      builder: (context, _) => MaterialApp(
        title: 'Twitch Drops Miner',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        // Wraps every screen with a custom, in-app Windows title bar (drag
        // area + minimize/maximize/close), replacing the native OS chrome.
        builder: (context, child) => Column(
          children: [
            const _CustomTitleBar(),
            Expanded(child: child ?? const SizedBox()),
          ],
        ),
        home: !_ready
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : _auth.isLoggedIn
                ? HomeScreen(auth: _auth, onLogout: () => setState(() {}))
                : LoginScreen(auth: _auth, onLoggedIn: () => setState(() {})),
      ),
    );
  }
}

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}

// A minimal custom title bar replacing the native Windows one: draggable
// area with the app name, plus minimize / maximize-restore / close buttons
// styled to match the app's theme instead of stock OS chrome.
class _CustomTitleBar extends StatefulWidget {
  const _CustomTitleBar();

  @override
  State<_CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<_CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMaximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      color: cs.surface,
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Twitch Drops Miner',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _TitleBarButton(
            icon: Icons.remove,
            tooltip: 'Réduire',
            onPressed: () => windowManager.minimize(),
          ),
          _TitleBarButton(
            icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            iconSize: _isMaximized ? 13 : 14,
            tooltip: _isMaximized ? 'Restaurer' : 'Agrandir',
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
          ),
          _TitleBarButton(
            icon: Icons.close,
            hoverColor: Colors.red,
            tooltip: 'Fermer (réduit dans la barre des tâches)',
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color? hoverColor;
  final VoidCallback onPressed;
  final String? tooltip;

  const _TitleBarButton({
    required this.icon,
    required this.onPressed,
    this.iconSize = 15,
    this.hoverColor,
    this.tooltip,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = widget.hoverColor ?? cs.surfaceContainerHighest;
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 46,
            height: 32,
            color: _hovered ? bg : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _hovered && widget.hoverColor != null
                  ? Colors.white
                  : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}