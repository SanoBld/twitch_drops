import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.auth, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Connect your Twitch account',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                const Text(
                  'Paste your auth-token cookie value from twitch.tv (devtools > Application > Cookies).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'auth-token',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (_controller.text.isEmpty) return;
                    await widget.auth.save(_controller.text.trim());
                    widget.onLoggedIn();
                  },
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
