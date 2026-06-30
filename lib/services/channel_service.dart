import '../models/channel.dart';
import 'gql_service.dart';

// Fetches live channels streaming a given game, used to pick what to mine.
// NOTE: needs a real sha256Hash captured from Twitch traffic (see README).
class ChannelService {
  final GqlService gql;
  ChannelService(this.gql);

  Future<List<Channel>> fetchLiveChannels(String gameSlug) async {
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

    final edges = res['data']?['game']?['streams']?['edges'] as List? ?? [];
    return edges.map((e) {
      final node = e['node'];
      return Channel(
        id: node['id'] ?? '',
        login: node['broadcaster']?['login'] ?? '',
        displayName: node['broadcaster']?['displayName'] ?? '',
        gameId: gameSlug,
        online: true,
        viewers: node['viewersCount'] ?? 0,
      );
    }).toList();
  }
}
