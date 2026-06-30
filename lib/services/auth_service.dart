import 'package:shared_preferences/shared_preferences.dart';

// Holds the Twitch access token obtained via device code login.
class AuthService {
  static const _key = 'twitch_auth_token';
  String? token;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_key);
  }

  Future<void> save(String newToken) async {
    token = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newToken);
  }

  Future<void> clear() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  bool get isLoggedIn => token != null && token!.isNotEmpty;
}
