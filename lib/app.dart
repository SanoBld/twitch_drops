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
      title: 'Twitch Drops',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _auth.isLoggedIn
              ? HomeScreen(auth: _auth)
              : LoginScreen(auth: _auth, onLoggedIn: () => setState(() {})),
    );
  }
}
