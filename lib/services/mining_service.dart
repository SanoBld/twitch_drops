import 'dart:async';
import '../models/channel.dart';
import '../models/drop_campaign.dart';
import 'gql_service.dart';
import 'channel_service.dart';
import 'settings_service.dart';

// Picks the best channel to mine based on the priority list, watches it
// with periodic pings, and switches automatically if it goes offline or a
// higher priority game becomes available. Mirrors TDM's auto-switch behavior.
class MiningService {
  final GqlService gql;
  late final ChannelService _channelService;
  final SettingsService _settings = SettingsService();

  Timer? _pingTimer;
  Timer? _switchCheckTimer;
  Channel? activeChannel;
  List<DropCampaign> _campaigns = [];
  final _statusController = StreamController<Channel?>.broadcast();

  // Listen to this to react to channel changes in the UI.
  Stream<Channel?> get onChannelChanged => _statusController.stream;

  MiningService(this.gql) {
    _channelService = ChannelService(gql);
  }

  Future<void> start(List<DropCampaign> campaigns) async {
    _campaigns = campaigns;
    await _pickBestChannel();
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _ping());
    _switchCheckTimer?.cancel();
    _switchCheckTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _pickBestChannel(),
    );
  }

  // Picks a live channel for the highest-priority game that still has
  // unclaimed drops, falling back to any available campaign if no
  // priority list is set (mirrors TDM's Priority Mode fallback).
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
      final channels = await _channelService.fetchLiveChannels(campaign.gameId);
      if (channels.isEmpty) continue;
      channels.sort((a, b) => b.viewers.compareTo(a.viewers));
      final candidate = channels.first;

      // Already mining the best option, nothing to do.
      if (activeChannel?.id == candidate.id) return;

      activeChannel = candidate;
      _statusController.add(activeChannel);
      return;
    }
  }

  Future<void> _ping() async {
    if (activeChannel == null) return;
    try {
      // Stream-less watch ping: tells Twitch we're "watching" without video.
      // NOTE: needs a real sha256Hash captured from Twitch traffic (see README).
      await gql.query('PlaybackAccessToken', {
        'login': activeChannel!.login,
        'isLive': true,
      });
    } catch (_) {
      // A failed ping likely means the channel went offline; re-pick next cycle.
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
