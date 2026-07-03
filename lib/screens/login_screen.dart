import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
      _codeInfo = null;
    });
    try {
      final info = await _deviceAuth.requestCode();
      if (!mounted) return;
      setState(() {
        _codeInfo = info;
        _loading = false;
      });

      // Auto-open browser with pre-filled code URL
      final uri = Uri.parse(info.verificationUri);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      final token = await _deviceAuth.pollForToken(
        info,
        shouldCancel: () => _cancelled,
      );
      if (!mounted || _cancelled) return;
      if (token == null) {
        setState(
            () => _error = 'Code expired or not approved. Tap to retry.');
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt,
                      color: cs.onPrimaryContainer, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Connect your Twitch account',
                    style: tt.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'A browser window will open automatically.\nEnter the code below on the Twitch activation page.',
                  style: tt.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (_loading && _codeInfo == null)
                  const CircularProgressIndicator(),

                if (_error != null) ...[
                  Icon(Icons.error_outline, color: cs.error, size: 32),
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],

                if (_codeInfo != null && _error == null) ...[
                  // Code display — tap to copy
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: _codeInfo!.userCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _codeInfo!.userCode,
                        style: tt.displaySmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          letterSpacing: 6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Tap code to copy',
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 24),

                  // Clickable URL
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final uri = Uri.parse(_codeInfo!.verificationUri);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_browser_outlined,
                              size: 16, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            _codeInfo!.verificationUri,
                            style: tt.bodySmall?.copyWith(
                              color: cs.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 10),
                      Text('Waiting for approval…',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
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
