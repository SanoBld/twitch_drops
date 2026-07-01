import 'dart:async';
import '../models/channel.dart';
import '../models/drop_campaign.dart';
import 'gql_service.dart';
import 'channel_service.dart';
import 'settings_service.dart';

// Mines drop campaigns by sending the Spade "minute-watched" GQL event once
// per minute, without streaming video. Mirrors TDM's stream-less approach.
class MiningService {
  final GqlService gql;
  late final ChannelService _channelService;
  final SettingsService _settings = SettingsService();

  Timer? _pingTimer;
  Timer? _switchCheckTimer;
  Channel? activeChannel;
  List<DropCampaign> _campaigns = [];
  String _userId = '';
  String _userLogin = '';

  final _statusController = StreamController<Channel?>.broadcast();
  Stream<Channel?> get onChannelChanged => _statusController.stream;

  MiningService(this.gql) {
    _channelService = ChannelService(gql);
  }

  Future<void> start(List<DropCampaign> campaigns) async {
    _campaigns = campaigns;

    // Fetch user info once so we can include it in minute-watched payloads.
    if (_userId.isEmpty) {
      final user = await gql.fetchCurrentUser();
      if (user != null) {
        _userId = user['id'] ?? '';
        _userLogin = user['login'] ?? '';
      }
    }

    await _pickBestChannel();

    _pingTimer?.cancel();
    // Send minute-watched every 60s (Twitch counts one minute per event).
    _pingTimer = Timer.periodic(const Duration(seconds: 60), (_) => _ping());

    _switchCheckTimer?.cancel();
    // Re-evaluate best channel every 2 minutes.
    _switchCheckTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _pickBestChannel(),
    );
  }

  Future<void> _pickBestChannel() async {
    final priority = await _settings.loadPriority();
    final eligible = _campaigns.where((c) => c.drops.any((d) => !d.claimed));
    if (eligible.isEmpty) return;

    final ordered = eligible.toList()
      ..sort((a, b) {
        final ai = priority.indexOf(a.gameId);
        final bi = priority.indexOf(b.gameId);
        final aRank = ai == -1 ? priority.length : ai;
        final bRank = bi == -1 ? priority.length : bi;
        return aRank.compareTo(bRank);
      });

    for (final campaign in ordered) {
      final channels = await _channelService.fetchLiveChannels(
        campaign.gameSlug,
        campaign.gameId,
        campaign.gameName,
      );
      if (channels.isEmpty) continue;
      channels.sort((a, b) => b.viewers.compareTo(a.viewers));
      final candidate = channels.first;

      if (activeChannel?.broadcastId == candidate.broadcastId) return;

      activeChannel = candidate;
      _statusController.add(activeChannel);

      // Send first ping immediately after switching channel.
      _ping();
      return;
    }
  }

  Future<void> _ping() async {
    final ch = activeChannel;
    if (ch == null || _userId.isEmpty) return;
    try {
      await gql.sendMinuteWatched(
        channelId: ch.id,
        broadcastId: ch.broadcastId,
        channelLogin: ch.login,
        gameId: ch.gameId,
        gameName: ch.gameName,
        userId: _userId,
        userLogin: _userLogin,
      );
    } catch (_) {
      // Failed ping likely means channel went offline; re-pick next cycle.
    }
  }

  void stop() {
    _pingTimer?.cancel();
    _switchCheckTimer?.cancel();
    activeChannel = null;
    _statusController.add(null);
  }

  void dispose() {
    stop();
    _statusController.close();
  }
}
