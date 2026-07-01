import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService {
  static const _priorityKey = 'priority_games';
  static const _minimizeToTrayKey = 'minimize_to_tray';

  Future<List<String>> loadPriority() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_priorityKey);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw));
  }

  Future<void> savePriority(List<String> gameIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_priorityKey, jsonEncode(gameIds));
  }

  Future<bool> getMinimizeToTray() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_minimizeToTrayKey) ?? true;
  }

  Future<void> setMinimizeToTray(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_minimizeToTrayKey, value);
  }
}
