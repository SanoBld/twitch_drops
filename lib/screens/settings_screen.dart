import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/drop_campaign.dart';
import '../services/auth_service.dart';
import '../services/autostart_service.dart';
import '../services/settings_service.dart';
import '../services/theme_settings.dart';
import '../main.dart' show trayService;
import '../app_strings.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService auth;
  final List<DropCampaign> campaigns;
  final VoidCallback onDisconnect;
  final VoidCallback? onLanguageChanged;

  const SettingsScreen({
    super.key,
    required this.auth,
    required this.campaigns,
    required this.onDisconnect,
    this.onLanguageChanged,
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
  String _language = 'fr';
  bool _notifyEmailEnabled = false;
  String _notifyEmailAddress = '';
  final _emailController = TextEditingController();
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
      _settings.loadLanguage(),
      _settings.loadNotifyEmailEnabled(),
      _settings.loadNotifyEmailAddress(),
    ]);
    setState(() {
      _autostartEnabled = results[0] as bool;
      _minimizeToTray = results[1] as bool;
      _priority = results[2] as List<String>;
      _version = results[3] as String;
      _language = results[4] as String;
      _notifyEmailEnabled = results[5] as bool;
      _notifyEmailAddress = results[6] as String;
      _emailController.text = _notifyEmailAddress;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _setLanguage(String code) async {
    setState(() => _language = code);
    await _settings.saveLanguage(code);
    AppStrings.instance.locale = code == 'fr' ? AppLocale.fr : AppLocale.en;
    widget.onLanguageChanged?.call();
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
        // ── Theme ────────────────────────────────────────────────────
        _SectionHeader(title: tr('theme')),
        AnimatedBuilder(
          animation: ThemeSettings(),
          builder: (context, _) => Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.palette_outlined),
                  title: Text(tr('theme_use_system')),
                  subtitle: Text(tr('theme_use_system_sub')),
                  value: ThemeSettings().useSystem,
                  onChanged: (v) => ThemeSettings().setUseSystem(v),
                ),
                if (!ThemeSettings().useSystem) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final c in _presetColors)
                          _ColorSwatch(
                            color: c,
                            selected: ThemeSettings().customColor.value == c.value,
                            onTap: () => ThemeSettings().setCustomColor(c),
                          ),
                        _CustomColorButton(
                          current: ThemeSettings().customColor,
                          onPicked: (c) => ThemeSettings().setCustomColor(c),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Language ─────────────────────────────────────────────────
        _SectionHeader(title: tr('language')),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.language, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'fr', label: Text('Français')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {_language},
                    onSelectionChanged: (s) => _setLanguage(s.first),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Account ──────────────────────────────────────────────────
        _SectionHeader(title: tr('connected_account')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(tr('connected_account')),
                subtitle: Text(
                  widget.auth.token != null ? tr('token_stored') : tr('not_connected'),
                  style: tt.bodySmall,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: cs.error),
                title: Text(tr('disconnect'), style: TextStyle(color: cs.error)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(tr('disconnect_confirm_title')),
                      content: Text(tr('disconnect_confirm_body')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(tr('cancel')),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: cs.error),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(tr('disconnect')),
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
        // ── Notifications ────────────────────────────────────────────
        _SectionHeader(title: tr('notifications')),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.mail_outline),
                title: Text(tr('notify_email')),
                subtitle: Text(tr('notify_email_sub')),
                value: _notifyEmailEnabled,
                onChanged: (v) async {
                  await _settings.saveNotifyEmailEnabled(v);
                  setState(() => _notifyEmailEnabled = v);
                },
              ),
              if (_notifyEmailEnabled) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: tr('notify_email_address'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => _notifyEmailAddress = v,
                    onEditingComplete: () => _settings.saveNotifyEmailAddress(_notifyEmailAddress),
                    onSubmitted: (v) => _settings.saveNotifyEmailAddress(v),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        _SectionHeader(title: tr('behavior')),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.rocket_launch_outlined),
                title: Text(tr('start_with_system')),
                subtitle: Text(tr('start_with_system_sub')),
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
                title: Text(tr('minimize_to_tray')),
                subtitle: Text(tr('minimize_to_tray_sub')),
                value: _minimizeToTray,
                onChanged: (v) async {
                  await _settings.setMinimizeToTray(v);
                  trayService.minimizeToTrayEnabled = v;
                  setState(() => _minimizeToTray = v);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── About ─────────────────────────────────────────────────────
        _SectionHeader(title: tr('about')),
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
                title: Text(tr('source_code')),
                subtitle: const Text('github.com/SanoBld/twitch_drops'),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

const _presetColors = [
  Colors.deepPurple, Colors.indigo, Colors.blue, Colors.teal,
  Colors.green, Colors.amber, Colors.deepOrange, Colors.red, Colors.pink,
];

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorSwatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
              : null,
        ),
        child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  final Color current;
  final ValueChanged<Color> onPicked;
  const _CustomColorButton({required this.current, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDialog<Color>(
          context: context,
          builder: (_) => _ColorPickerDialog(initial: current),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          gradient: const SweepGradient(
            colors: [Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red],
          ),
        ),
        child: const Icon(Icons.add, size: 16, color: Colors.white),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _hue = HSVColor.fromColor(widget.initial).hue;

  @override
  Widget build(BuildContext context) {
    final preview = HSVColor.fromAHSV(1, _hue, 0.8, 0.9).toColor();
    return AlertDialog(
      title: Text(tr('pick_color')),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 60, height: 60,
                decoration: BoxDecoration(color: preview, shape: BoxShape.circle)),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 14,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _hue, min: 0, max: 360,
                activeColor: preview,
                onChanged: (v) => setState(() => _hue = v),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, preview), child: Text(tr('confirm'))),
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