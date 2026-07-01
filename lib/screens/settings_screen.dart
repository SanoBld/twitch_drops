import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/drop_campaign.dart';
import '../services/auth_service.dart';
import '../services/autostart_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService auth;
  final List<DropCampaign> campaigns;
  final VoidCallback onDisconnect;

  const SettingsScreen({
    super.key,
    required this.auth,
    required this.campaigns,
    required this.onDisconnect,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _autostart = AutostartService();

  bool _autostartEnabled = false;
  bool _minimizeToTray = true;
  List<String> _priority = [];
  String _version = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _autostart.isEnabled(),
      _settings.getMinimizeToTray(),
      _settings.loadPriority(),
      PackageInfo.fromPlatform().then((i) => '${i.version}+${i.buildNumber}'),
    ]);
    setState(() {
      _autostartEnabled = results[0] as bool;
      _minimizeToTray = results[1] as bool;
      _priority = results[2] as List<String>;
      _version = results[3] as String;
      _loading = false;
    });
  }

  Future<void> _savePriority(List<String> order) async {
    await _settings.savePriority(order);
    setState(() => _priority = order);
  }

  String _gameName(String gameId) {
    try {
      return widget.campaigns.firstWhere((c) => c.gameId == gameId).gameName;
    } catch (_) {
      return gameId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Account ──────────────────────────────────────────────────
        _SectionHeader(title: 'Account'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Connected account'),
                subtitle: Text(
                  widget.auth.token != null
                      ? 'Token stored'
                      : 'Not connected',
                  style: tt.bodySmall,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: cs.error),
                title: Text('Disconnect',
                    style: TextStyle(color: cs.error)),
                subtitle: const Text('Remove stored credentials'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Disconnect?'),
                      content: const Text(
                          'This will remove your stored token. You will need to log in again.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: cs.error),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await widget.auth.clear();
                    widget.onDisconnect();
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Behavior ─────────────────────────────────────────────────
        _SectionHeader(title: 'Behavior'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.rocket_launch_outlined),
                title: const Text('Start with system'),
                subtitle: const Text('Launch automatically at login'),
                value: _autostartEnabled,
                onChanged: (v) async {
                  if (v) {
                    await _autostart.enable();
                  } else {
                    await _autostart.disable();
                  }
                  setState(() => _autostartEnabled = v);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.minimize_outlined),
                title: const Text('Minimize to tray on close'),
                subtitle:
                    const Text('Keep mining in background when window is closed'),
                value: _minimizeToTray,
                onChanged: (v) async {
                  await _settings.setMinimizeToTray(v);
                  setState(() => _minimizeToTray = v);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Game priority ─────────────────────────────────────────────
        _SectionHeader(title: 'Game priority'),
        Card(
          child: _priority.isEmpty
              ? const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('No active campaigns'),
                  subtitle: Text(
                      'Priority list will appear once campaigns are loaded'),
                )
              : ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorder: (oldIndex, newIndex) {
                    final newOrder = List<String>.from(_priority);
                    if (newIndex > oldIndex) newIndex--;
                    final item = newOrder.removeAt(oldIndex);
                    newOrder.insert(newIndex, item);
                    _savePriority(newOrder);
                  },
                  children: [
                    for (var i = 0; i < _priority.length; i++)
                      ListTile(
                        key: ValueKey(_priority[i]),
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text(_gameName(_priority[i])),
                        trailing: const Icon(Icons.drag_handle),
                      ),
                  ],
                ),
        ),

        const SizedBox(height: 20),

        // ── About ─────────────────────────────────────────────────────
        _SectionHeader(title: 'About'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Twitch Drops Miner'),
                subtitle: Text('Version $_version'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code_outlined),
                title: const Text('Source code'),
                subtitle: const Text('github.com/SanoBld/twitch_drops'),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () {
                  // url_launcher already in pubspec
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
