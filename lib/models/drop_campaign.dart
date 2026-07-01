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

  bool get isActive => status == 'ACTIVE';

  factory DropCampaign.fromJson(Map<String, dynamic> j) {
    return DropCampaign(
      id: j['id'] ?? '',
      gameName: j['game']?['name'] ?? '',
      gameId: j['game']?['id'] ?? '',
      gameSlug: j['game']?['slug'] ?? '',
      name: j['name'] ?? '',
      status: j['status'] ?? '',
      endAt: DateTime.tryParse(j['endAt'] ?? '') ?? DateTime.now(),
      drops: ((j['timeBasedDrops'] ?? []) as List)
          .map((d) => TimeBasedDrop.fromJson(d))
          .toList(),
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
    final self = j['self'] as Map<String, dynamic>? ?? {};
    return TimeBasedDrop(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      requiredMinutes: j['requiredMinutesWatched'] ?? 0,
      currentMinutes: self['currentMinutesWatched'] ?? 0,
      claimed: self['isClaimed'] ?? false,
    );
  }

  double get progress =>
      requiredMinutes == 0 ? 0 : (currentMinutes / requiredMinutes).clamp(0.0, 1.0);

  int get remainingMinutes => (requiredMinutes - currentMinutes).clamp(0, requiredMinutes);
}
