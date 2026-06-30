import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/device_auth_service.dart';

class LoginScreen extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onLoggedIn;
  const LoginScreen({super.key, required this.auth, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _deviceAuth = DeviceAuthService();
  DeviceCodeInfo? _codeInfo;
  bool _loading = false;
  bool _cancelled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await _deviceAuth.requestCode();
      if (!mounted) return;
      setState(() {
        _codeInfo = info;
        _loading = false;
      });
      final token = await _deviceAuth.pollForToken(
        info,
        shouldCancel: () => _cancelled,
      );
      if (!mounted || _cancelled) return;
      if (token == null) {
        setState(() => _error = 'Code expired or not approved in time. Try again.');
        return;
      }
      await widget.auth.save(token);
      widget.onLoggedIn();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach Twitch. Check your connection and retry.';
      });
    }
  }

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
                if (_loading) const CircularProgressIndicator(),
                if (_error != null) ...[
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _start, child: const Text('Retry')),
                ],
                if (_codeInfo != null && _error == null) ...[
                  Text('Go to ${_codeInfo!.verificationUri} and enter this code:',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _codeInfo!.userCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _codeInfo!.userCode,
                        style: const TextStyle(fontSize: 28, letterSpacing: 4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tap the code to copy it. Waiting for approval...',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
