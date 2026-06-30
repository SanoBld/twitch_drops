import '../models/channel.dart';
import 'gql_service.dart';

// Fetches live channels streaming a given game, used to pick what to mine.
// NOTE: needs a real sha256Hash captured from Twitch traffic (see README).
class ChannelService {
  final GqlService gql;
  ChannelService(this.gql);

  Future<List<Channel>> fetchLiveChannels(String gameId) async {
    final res = await gql.query('DirectoryPage_Game', {
      'slug': gameId,
      'options': {
        'sort': 'VIEWER_COUNT',
        'recommendationsContext': {'platform': 'web'},
      },
      'limit': 30,
    });

    final edges = res['data']?['game']?['streams']?['edges'] as List? ?? [];
    return edges.map((e) {
      final node = e['node'];
      return Channel(
        id: node['id'] ?? '',
        login: node['broadcaster']?['login'] ?? '',
        displayName: node['broadcaster']?['displayName'] ?? '',
        gameId: gameId,
        online: true,
        viewers: node['viewersCount'] ?? 0,
      );
    }).toList();
  }
}
