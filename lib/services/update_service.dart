import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Checks GitHub Releases for a newer version than the one currently installed.
class UpdateService {
  static const _repo = 'SanoBld/twitch_drops'; // change if repo name differs
  final Dio _dio = Dio();

  Future<UpdateInfo?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    final res = await _dio.get(
      'https://api.github.com/repos/$_repo/releases/latest',
    );
    final data = res.data as Map<String, dynamic>;
    final latestTag = (data['tag_name'] as String).replaceFirst('v', '');

    if (_isNewer(latestTag, currentVersion)) {
      final assets = (data['assets'] as List?) ?? [];
      String? downloadUrl;
      for (final a in assets) {
        final name = a['name'] as String;
        if (name.contains('windows') || name.contains('linux')) {
          downloadUrl = a['browser_download_url'];
          break;
        }
      }
      return UpdateInfo(
        version: latestTag,
        url: downloadUrl ?? data['html_url'],
        notes: data['body'] ?? '',
      );
    }
    return null;
  }

  bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.tryParse).toList();
    final c = current.split('.').map(int.tryParse).toList();
    for (var i = 0; i < l.length; i++) {
      final lv = l[i] ?? 0;
      final cv = i < c.length ? (c[i] ?? 0) : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}

class UpdateInfo {
  final String version;
  final String url;
  final String notes;
  UpdateInfo({required this.version, required this.url, required this.notes});
}
