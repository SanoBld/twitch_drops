class DropCampaign {
  final String id;
  final String gameName;
  final String gameId;
  final String gameSlug;
  final String name;
  final String status;
  final DateTime endAt;
  final List<TimeBasedDrop> drops;

  DropCampaign({
    required this.id,
    required this.gameName,
    required this.gameId,
    required this.gameSlug,
    required this.name,
    required this.status,
    required this.endAt,
    required this.drops,
  });

  bool get isActive => status.isEmpty || status == 'ACTIVE';

  factory DropCampaign.fromJson(Map<String, dynamic> j) {
    // Drops can be under 'timeBasedDrops' or 'drops' depending on API version
    final rawDrops = (j['timeBasedDrops'] ?? j['drops'] ?? []) as List;
    return DropCampaign(
      id: j['id'] ?? '',
      gameName: j['game']?['name'] ?? j['gameName'] ?? '',
      gameId: j['game']?['id'] ?? j['gameId'] ?? '',
      gameSlug: j['game']?['slug'] ?? j['gameSlug'] ?? '',
      name: j['name'] ?? '',
      status: j['status'] ?? '',
      endAt: DateTime.tryParse(j['endAt'] ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      drops: rawDrops.map((d) => TimeBasedDrop.fromJson(d)).toList(),
    );
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
    final self = (j['self'] ?? j['userDropInventory'] ?? {}) as Map<String, dynamic>;
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
