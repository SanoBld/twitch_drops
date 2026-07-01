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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twitch Drops Miner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF9146FF), // Twitch purple
        useMaterial3: true,
        brightness: Brightness.dark,
        cardTheme: const CardThemeData(elevation: 0),
      ),
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
