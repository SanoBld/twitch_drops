import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';
import 'settings_service.dart';

// Global reactive theme accent color. Falls back to the OS accent color
// (with its own built-in Twitch-purple fallback) until the user picks a
// custom color, or switches back to "system" at any time.
class ThemeSettings extends ChangeNotifier {
  static final ThemeSettings instance = ThemeSettings._();
  factory ThemeSettings() => instance;
  ThemeSettings._();

  final _settings = SettingsService();

  bool useSystem = true;
  Color customColor = Colors.deepPurple;

  Color get seed => useSystem ? SystemTheme.accentColor.accent : customColor;

  Future<void> load() async {
    useSystem = await _settings.loadUseSystemTheme();
    final stored = await _settings.loadCustomColor();
    if (stored != null) customColor = Color(stored);
    notifyListeners();
  }

  Future<void> setUseSystem(bool value) async {
    useSystem = value;
    await _settings.saveUseSystemTheme(value);
    notifyListeners();
  }

  Future<void> setCustomColor(Color color) async {
    customColor = color;
    useSystem = false;
    await _settings.saveUseSystemTheme(false);
    await _settings.saveCustomColor(color.value);
    notifyListeners();
  }
}