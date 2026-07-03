import '../models/drop_campaign.dart';
import 'gql_service.dart';
import 'log_service.dart';

class CampaignService {
  final GqlService gql;
  final _log = LogService();

  CampaignService(this.gql);

  Future<List<DropCampaign>> fetchCampaigns() async {
    // Step 1: get the list of campaigns (summary only — no drop details).
    // NOTE: hash below MUST match Twitch's current persisted query hash for
    // ViewerDropsDashboard, otherwise Twitch returns PersistedQueryNotFound
    // and 'data' comes back null/empty, which looks like "no drops found".
    final res = await gql.query(
      'ViewerDropsDashboard',
      {'fetchRewardCampaigns': false},
      sha256Hash:
          '5a4da2ab3d5b47c9f9ce864e727b2cb346af1e3ea8b897fe8f704a97ff017619',
    );

    _log.log('ViewerDropsDashboard raw: $res', tag: 'CampaignService');

    if (res['errors'] != null) {
      _log.log('GQL errors: ${res['errors']}', tag: 'CampaignService');
    }

    final user = res['data']?['currentUser'];
    if (user == null) {
      _log.log(
        'currentUser is null — token invalid OR wrong persisted query hash',
        tag: 'CampaignService',
      );
      return [];
    }

    final userLogin = user['login']?.toString() ?? '';
    _log.log('Logged in as: $userLogin', tag: 'CampaignService');

    final rawList = (user['dropCampaigns'] as List?) ??
        (user['inventory']?['dropCampaignsInProgress'] as List?) ??
        [];

    _log.log('Found ${rawList.length} raw campaigns (summary)',
        tag: 'CampaignService');

    // Keep only campaigns that are ACTIVE or UPCOMING at the summary level,
    // same filter TDM applies before bothering to fetch full details.
    final candidates = rawList.where((c) {
      final status = (c as Map<String, dynamic>)['status'] as String?;
      return status == null || status == 'ACTIVE' || status == 'UPCOMING';
    }).toList();

    _log.log('${candidates.length} candidates after status pre-filter',
        tag: 'CampaignService');

    // Step 2: fetch full details (timeBasedDrops + self progress) per
    // campaign. ViewerDropsDashboard alone never has this data.
    final campaigns = <DropCampaign>[];
    for (final c in candidates) {
      final id = (c as Map<String, dynamic>)['id'] as String?;
      final name = c['name']?.toString() ?? '?';
      if (id == null || userLogin.isEmpty) continue;
      try {
        final detailRes = await gql.fetchCampaignDetails(
          channelLogin: userLogin,
          dropId: id,
        );
        final campaignJson = detailRes['data']?['user']?['dropCampaign'];
        if (detailRes['errors'] != null) {
          _log.log(
              'CampaignDetails errors for "$name": ${detailRes['errors']}',
              tag: 'CampaignService');
        }
        if (campaignJson == null) {
          _log.log('No details for campaign "$name" ($id), using summary',
              tag: 'CampaignService');
          campaigns.add(DropCampaign.fromJson(c));
          continue;
        }
        campaigns
            .add(DropCampaign.fromJson(campaignJson as Map<String, dynamic>));
      } catch (e) {
        _log.log('fetchCampaignDetails threw for "$name" ($id): $e',
            tag: 'CampaignService');
        campaigns.add(DropCampaign.fromJson(c));
      }
    }

    for (final c in campaigns) {
      _log.log(
        'Campaign: ${c.name} | game: ${c.gameName} | status: "${c.status}" '
        '| drops: ${c.drops.length} | endAt: ${c.endAt}',
        tag: 'CampaignService',
      );
    }

    final now = DateTime.now();
    final filtered = campaigns.where((c) {
      final statusOk =
          c.status.isEmpty || c.status == 'ACTIVE' || c.status == 'UPCOMING';
      final notExpired = c.endAt.isAfter(now);
      final hasUnclaimed = c.drops.isEmpty || c.drops.any((d) => !d.claimed);
      return statusOk && notExpired && hasUnclaimed;
    }).toList();

    _log.log('After filter: ${filtered.length} campaigns',
        tag: 'CampaignService');
    return filtered;
  }
}