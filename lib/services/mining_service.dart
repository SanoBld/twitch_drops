import 'dart:async';
import '../models/channel.dart';
import '../models/drop_campaign.dart';
import 'gql_service.dart';

// Simulates watching a channel to progress drops, without streaming video.
class MiningService {
  final GqlService gql;
  Timer? _timer;
  Channel? activeChannel;

  MiningService(this.gql);

  void startMining(Channel channel, List<DropCampaign> campaigns) {
    activeChannel = channel;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _ping());
  }

  Future<void> _ping() async {
    if (activeChannel == null) return;
    // Sends a minimal watch event, equivalent to TDM's stream-less watch ping.
    await gql.query('PlaybackAccessToken', {
      'login': activeChannel!.login,
      'isLive': true,
    });
  }

  void stop() {
    _timer?.cancel();
    activeChannel = null;
  }
}
