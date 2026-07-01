class Channel {
  final String id;          // broadcaster channel ID (node['broadcaster']['id'])
  final String broadcastId; // stream/broadcast ID (node['id'] from stream node)
  final String login;
  final String displayName;
  final String gameId;
  final String gameName;
  bool online;
  int viewers;

  Channel({
    required this.id,
    required this.broadcastId,
    required this.login,
    required this.displayName,
    required this.gameId,
    required this.gameName,
    this.online = false,
    this.viewers = 0,
  });
}
