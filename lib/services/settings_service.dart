import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Stores priority game list and app preferences.
class SettingsService {
  static const _priorityKey = 'priority_games';

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
}
