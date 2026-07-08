import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/drop_campaign.dart';
import '../services/auth_service.dart';
import '../services/autostart_service.dart';
import '../services/settings_service.dart';
import '../services/theme_settings.dart';
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
    ]);
    setState(() {
      _autostartEnabled = results[0] as bool;
      _minimizeToTray = results[1] as bool;
      _priority = results[2] as List<String>;
      _version = results[3] as String;
      _language = results[4] as String;
      _loading = false;
    });
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
                  secondary: const SizedBox.shrink(),
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
                SizedBox.shrink(),
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
                leading: const SizedBox.shrink(),
                title: Text(tr('connected_account')),
                subtitle: Text(
                  widget.auth.token != null ? tr('token_stored') : tr('not_connected'),
                  style: tt.bodySmall,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: SizedBox.shrink(),
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
        _SectionHeader(title: tr('behavior')),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const SizedBox.shrink(),
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
                secondary: const SizedBox.shrink(),
                title: Text(tr('minimize_to_tray')),
                subtitle: Text(tr('minimize_to_tray_sub')),
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

        // ── About ─────────────────────────────────────────────────────
        _SectionHeader(title: tr('about')),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const SizedBox.shrink(),
                title: const Text('Twitch Drops Miner'),
                subtitle: Text('Version $_version'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const SizedBox.shrink(),
                title: Text(tr('source_code')),
                subtitle: const Text('github.com/SanoBld/twitch_drops'),
                trailing: const SizedBox.shrink(),
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
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.amber,
  Colors.deepOrange,
  Colors.red,
  Colors.pink,
];

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ColorSwatch(
      {required this.color, required this.selected, required this.onTap});

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
        child: selected ? const SizedBox.shrink() : null,
      ),
    );
  }
}

// Opens a simple HSV color picker dialog (hue slider + shade grid) so the
// user can pick ANY color, not just the presets.
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
        child: const SizedBox.shrink(),
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
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: preview, shape: BoxShape.circle),
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 14,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _hue,
                min: 0,
                max: 360,
                activeColor: preview,
                onChanged: (v) => setState(() => _hue = v),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, preview),
          child: Text(tr('confirm')),
        ),
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