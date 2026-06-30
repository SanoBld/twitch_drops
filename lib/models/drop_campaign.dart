class DropCampaign {
  final String id;
  final String gameName;
  final String gameId;
  final String gameSlug;
  final String name;
  final DateTime endAt;
  final List<TimeBasedDrop> drops;

  DropCampaign({
    required this.id,
    required this.gameName,
    required this.gameId,
    required this.gameSlug,
    required this.name,
    required this.endAt,
    required this.drops,
  });

  factory DropCampaign.fromJson(Map<String, dynamic> j) {
    return DropCampaign(
      id: j['id'] ?? '',
      gameName: j['game']?['name'] ?? '',
      gameId: j['game']?['id'] ?? '',
      gameSlug: j['game']?['slug'] ?? '',
      name: j['name'] ?? '',
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
    return TimeBasedDrop(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      requiredMinutes: j['requiredMinutesWatched'] ?? 0,
    );
  }

  double get progress =>
      requiredMinutes == 0 ? 0 : (currentMinutes / requiredMinutes).clamp(0, 1);
}
