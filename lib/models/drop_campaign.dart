class DropCampaign {
  final String id;
  final String gameName;
  final String gameId;
  final String gameSlug;
  final String name;
  final String status;
  final DateTime endAt;
  final List<TimeBasedDrop> drops;
  // Whether the user's Twitch account is linked to the game's publisher
  // account. If false, watching streams will NEVER progress this drop,
  // no matter how long you mine it — Twitch silently ignores progress
  // for unlinked accounts.
  final bool isAccountConnected;
  final String boxArtUrl;

  DropCampaign({
    required this.id,
    required this.gameName,
    required this.gameId,
    required this.gameSlug,
    required this.name,
    required this.status,
    required this.endAt,
    required this.drops,
    this.isAccountConnected = true,
    this.boxArtUrl = '',
  });

  bool get isActive => status.isEmpty || status == 'ACTIVE';

  factory DropCampaign.fromJson(Map<String, dynamic> j) {
    // Drops can be under 'timeBasedDrops' or 'drops' depending on API version
    final rawDrops = (j['timeBasedDrops'] ?? j['drops'] ?? []) as List;
    final rawGame = j['game'];
    final game = rawGame == null ? null : Map<String, dynamic>.from(rawGame as Map);

    // Twitch's ViewerDropsDashboard/DropCampaignDetails responses expose
    // the game name as 'displayName', not 'name'. Fall back to 'name' /
    // 'gameName' just in case a different query shape is ever used.
    final gameName = game?['displayName'] ?? game?['name'] ?? j['gameName'] ?? '';

    // The API doesn't return a directory slug for the game in this query.
    // Twitch's actual directory slugs are (almost always) just the kebab
    // case of the display name, so derive it the same way when it's not
    // provided directly.
    final rawSlug = game?['slug'] ?? j['gameSlug'];
    final gameSlug = (rawSlug != null && (rawSlug as String).isNotEmpty)
        ? rawSlug
        : _slugify(gameName as String);

    final rawSelf = j['self'];
    final self = rawSelf == null ? null : Map<String, dynamic>.from(rawSelf as Map);

    return DropCampaign(
      id: j['id'] ?? '',
      gameName: gameName,
      gameId: game?['id'] ?? j['gameId'] ?? '',
      gameSlug: gameSlug,
      name: j['name'] ?? '',
      status: j['status'] ?? '',
      endAt: DateTime.tryParse(j['endAt'] ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      drops: rawDrops
          .map((d) => TimeBasedDrop.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      // Default to true when unknown, so we don't accidentally hide a
      // campaign just because this specific field was missing.
      isAccountConnected: self?['isAccountConnected'] as bool? ?? true,
      boxArtUrl: game?['boxArtURL']?.toString() ?? '',
    );
  }

  // Approximates Twitch's directory slug format: lowercase, spaces and
  // most punctuation become single dashes, no leading/trailing dashes.
  // e.g. "Call of Duty: Warzone" -> "call-of-duty-warzone"
  static String _slugify(String name) {
    final lower = name.toLowerCase().trim();
    final replaced = lower.replaceAll(RegExp(r"[^a-z0-9]+"), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

class TimeBasedDrop {
  final String id;
  final String name;
  final int requiredMinutes;
  int currentMinutes;
  bool claimed;

  TimeBasedDrop({
    required this.id,
    required this.name,
    required this.requiredMinutes,
    this.currentMinutes = 0,
    this.claimed = false,
  });

  factory TimeBasedDrop.fromJson(Map<String, dynamic> j) {
    // Progress lives under 'self' object
    final rawSelf = j['self'] ?? j['userDropInventory'];
    final self = rawSelf == null ? <String, dynamic>{} : Map<String, dynamic>.from(rawSelf as Map);
    return TimeBasedDrop(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      requiredMinutes: j['requiredMinutesWatched'] ?? j['requiredMinutes'] ?? 0,
      currentMinutes: self['currentMinutesWatched'] ?? self['currentMinutes'] ?? 0,
      claimed: self['isClaimed'] ?? self['claimed'] ?? false,
    );
  }

  double get progress =>
      requiredMinutes == 0 ? 0 : (currentMinutes / requiredMinutes).clamp(0.0, 1.0);

  int get remainingMinutes =>
      (requiredMinutes - currentMinutes).clamp(0, requiredMinutes);
}