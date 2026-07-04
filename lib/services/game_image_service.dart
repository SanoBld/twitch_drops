import 'dart:convert';
import 'package:dio/dio.dart';
import 'log_service.dart';

// Fetches game cover art from an external, non-Twitch source, used as a
// fallback whenever Twitch's own boxArtURL fails to load (or is missing).
// Steam's public store-search endpoint requires no API key and covers a
// large fraction of the games that run drop campaigns.
class GameImageService {
  static final GameImageService instance = GameImageService._();
  factory GameImageService() => instance;
  GameImageService._();

  final Dio _dio = Dio();
  final _log = LogService();

  // In-memory cache: gameName -> image URL (or null if none found), so we
  // never hit the network twice for the same game in one session.
  final Map<String, String?> _cache = {};

  Future<String?> fetchFallbackImage(String gameName) async {
    if (gameName.isEmpty) return null;
    if (_cache.containsKey(gameName)) return _cache[gameName];

    try {
      final res = await _dio.get(
        'https://store.steampowered.com/api/storesearch/',
        queryParameters: {'term': gameName, 'l': 'english', 'cc': 'us'},
      );
      final data = res.data is String ? jsonDecode(res.data) : res.data;
      final items = data['items'] as List?;
      if (items == null || items.isEmpty) {
        _cache[gameName] = null;
        return null;
      }
      final appId = items.first['id'];
      // Steam's CDN header image — wide, high quality, no key needed.
      final url =
          'https://cdn.cloudflare.steamstatic.com/steam/apps/$appId/header.jpg';
      _cache[gameName] = url;
      return url;
    } catch (e) {
      _log.log('GameImageService fallback failed for "$gameName": $e',
          tag: 'GameImageService');
      _cache[gameName] = null;
      return null;
    }
  }
}
