import 'package:flutter/material.dart';
import 'services/auth_service.dart';
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

  // A warmer, more "alive" accent than plain Twitch purple — still reads
  // as Twitch but with more character.
  static const _seed = Color(0xFF9146FF);

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      // Give action colors (mining active, success, danger) more presence
      // instead of pure Material defaults.
      primary: brightness == Brightness.dark
          ? const Color(0xFFA970FF)
          : const Color(0xFF7B2FE0),
      secondary: brightness == Brightness.dark
          ? const Color(0xFF35D07F) // organic green for "live/active"
          : const Color(0xFF1E9A5C),
      tertiary: brightness == Brightness.dark
          ? const Color(0xFFFFB454) // warm amber for "expiring soon"
          : const Color(0xFFE08A1E),
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.comfortable,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.secondary : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? scheme.secondary.withValues(alpha: 0.4)
                : null),
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // Fade instead of the mobile-style slide-up-from-bottom — reads
          // as a desktop app, not a phone.
          TargetPlatform.windows: FadeThroughPageTransitionBuilder(),
          TargetPlatform.linux: FadeThroughPageTransitionBuilder(),
          TargetPlatform.macOS: FadeThroughPageTransitionBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twitch Drops Miner',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // follows Windows light/dark automatically
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _auth.isLoggedIn
              ? HomeScreen(
                  auth: _auth,
                  onLogout: () => setState(() {}),
                )
              : LoginScreen(
                  auth: _auth,
                  onLoggedIn: () => setState(() {}),
                ),
    );
  }
}

// A gentle cross-fade transition (used instead of Material's default
// mobile-oriented slide transition) — feels calmer and more "desktop".
class FadeThroughPageTransitionBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionBuilder();

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