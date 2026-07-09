import 'package:flutter/material.dart';
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

  // Single, coherent seed: the user's actual Windows accent color (falls
  // back to Twitch purple on platforms where it isn't available). Material
  // 3 derives ALL the other tones (secondary, tertiary, containers, etc.)
  // from this one seed automatically, so nothing clashes — no more manually
  // hand-picked colors fighting each other.
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
    return AnimatedBuilder(
      animation: ThemeSettings(),
      builder: (context, _) => MaterialApp(
        title: 'Twitch Drops Miner',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        // Android-style "stretch" effect instead of iOS's rubber-band
        // bounce when a list is scrolled past its start/end.
        scrollBehavior: _AppScrollBehavior(),
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

// Android 12+ "stretch" overscroll everywhere, instead of iOS's bounce —
// applies to every scrollable in the app via MaterialApp.scrollBehavior.
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}