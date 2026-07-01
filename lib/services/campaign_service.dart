import '../models/drop_campaign.dart';
import 'gql_service.dart';

class CampaignService {
  final GqlService gql;
  CampaignService(this.gql);

  Future<List<DropCampaign>> fetchCampaigns() async {
    final res = await gql.query(
      'ViewerDropsDashboard',
      {'fetchRewardCampaigns': true},
      sha256Hash:
          'd9cae7761dafab85908c85e6683cb4201b449e66ac3bb5e894f15ff12aeafaa7',
    );

    // Try primary path first, fall back to inventory path used by some API versions.
    final rawList = (res['data']?['currentUser']?['dropCampaigns'] as List?) ??
        (res['data']?['currentUser']?['inventory']?['dropCampaignsInProgress']
            as List?) ??
        [];

    final campaigns = rawList
        .map((c) => DropCampaign.fromJson(c as Map<String, dynamic>))
        .toList();

    // Only keep ACTIVE campaigns that still have unclaimed drops.
    return campaigns
        .where((c) => c.isActive && c.drops.any((d) => !d.claimed))
        .toList();
  }
}
