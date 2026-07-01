import '../models/channel.dart';
import 'gql_service.dart';

// Fetches live channels streaming a given game slug.
class ChannelService {
  final GqlService gql;
  ChannelService(this.gql);

  Future<List<Channel>> fetchLiveChannels(
      String gameSlug, String gameId, String gameName) async {
    final res = await gql.query(
      'DirectoryPage_Game',
      {
        'slug': gameSlug,
        'imageWidth': 50,
        'includeCostreaming': true,
        'limit': 30,
        'sortTypeIsRecency': false,
        'options': {
          'includeRestricted': ['SUB_ONLY_LIVE'],
          'sort': 'VIEWER_COUNT',
          'recommendationsContext': {'platform': 'web'},
        },
      },
      sha256Hash:
          '86bcceb4e8b1a51256ff8eed8bd8aae4acacf80d737efe904f84f3aeadf8cafd',
    );

    final edges =
        res['data']?['game']?['streams']?['edges'] as List? ?? [];
    return edges.map((e) {
      final node = e['node'];
      final broadcaster = node['broadcaster'] ?? {};
      return Channel(
        // node['id'] is the broadcast/stream ID, broadcaster['id'] is the channel ID
        id: broadcaster['id']?.toString() ?? '',
        broadcastId: node['id']?.toString() ?? '',
        login: broadcaster['login'] ?? '',
        displayName: broadcaster['displayName'] ?? '',
        gameId: gameId,
        gameName: gameName,
        online: true,
        viewers: node['viewersCount'] ?? 0,
      );
    }).toList();
  }
}
