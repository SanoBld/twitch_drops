class Channel {
  final String id;
  final String login;
  final String displayName;
  final String gameId;
  bool online;
  int viewers;

  Channel({
    required this.id,
    required this.login,
    required this.displayName,
    required this.gameId,
    this.online = false,
    this.viewers = 0,
  });
}
