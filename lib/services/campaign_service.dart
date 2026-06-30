import '../models/drop_campaign.dart';
import 'gql_service.dart';

// Fetches drop campaigns the logged-in account can mine.
class CampaignService {
  final GqlService gql;
  CampaignService(this.gql);

  Future<List<DropCampaign>> fetchCampaigns() async {
    final res = await gql.query('ViewerDropsDashboard', {});
    final list = res['data']?['currentUser']?['dropCampaigns'] as List? ?? [];
    return list.map((c) => DropCampaign.fromJson(c)).toList();
  }
}
