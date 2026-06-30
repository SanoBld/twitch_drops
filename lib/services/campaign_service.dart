import '../models/drop_campaign.dart';
import 'gql_service.dart';

// Fetches drop campaigns the logged-in account can mine.
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
    final list = res['data']?['currentUser']?['dropCampaigns'] as List? ?? [];
    return list.map((c) => DropCampaign.fromJson(c)).toList();
  }
}
