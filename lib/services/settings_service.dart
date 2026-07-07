import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum SortMode { expiringSoonest, mostViewers, alphabetical }

class SettingsService {
  static const _priorityKey = 'priority_games';
  static const _minimizeToTrayKey = 'minimize_to_tray';
  static const _excludedGamesKey = 'excluded_games';
  static const _sortModeKey = 'sort_mode';
  static const _languageKey = 'app_language'; // 'en' | 'fr'

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

  // ── Excluded games (never auto-mined) ─────────────────────────────
  Future<Set<String>> loadExcludedGames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_excludedGamesKey);
    if (raw == null) return {};
    return Set<String>.from(jsonDecode(raw));
  }

  Future<void> saveExcludedGames(Set<String> gameIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_excludedGamesKey, jsonEncode(gameIds.toList()));
  }

  // ── Sort mode ──────────────────────────────────────────────────────
  Future<SortMode> loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sortModeKey);
    return SortMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => SortMode.expiringSoonest,
    );
  }

  Future<void> saveSortMode(SortMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortModeKey, mode.name);
  }

  // ── Language ───────────────────────────────────────────────────────
  Future<String> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'fr';
  }

  Future<void> saveLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
  }

  // ── Theme (system accent vs custom color) ─────────────────────────
  static const _themeUseSystemKey = 'theme_use_system';
  static const _themeCustomColorKey = 'theme_custom_color';

  Future<bool> loadUseSystemTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeUseSystemKey) ?? true;
  }

  Future<void> saveUseSystemTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeUseSystemKey, value);
  }

  // Stored as 0xAARRGGBB int.
  Future<int?> loadCustomColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeCustomColorKey);
  }

  Future<void> saveCustomColor(int argb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeCustomColorKey, argb);
  }
}