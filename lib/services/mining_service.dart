import 'dart:async';
import '../models/channel.dart';
import '../models/drop_campaign.dart';
import 'gql_service.dart';
import 'channel_service.dart';
import 'settings_service.dart';
import 'log_service.dart';

// Mines drop campaigns by sending the Spade "minute-watched" GQL event once
// per minute, without streaming video. Mirrors TDM's stream-less approach.
class MiningService {
  final GqlService gql;
  late final ChannelService _channelService;
  final SettingsService _settings = SettingsService();
  final _log = LogService();

  Timer? _pingTimer;
  Timer? _switchCheckTimer;
  Channel? activeChannel;
  List<DropCampaign> _campaigns = [];
  String _userId = '';
  String _userLogin = '';

  // When true (default), the service picks the best campaign/channel on
  // its own. When false, it only mines whatever was set manually via
  // mineCampaign(), and never auto-switches.
  bool autoMiningEnabled = true;
  DropCampaign? _manualCampaign;

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

  // Toggles automatic campaign/channel selection. Turning it off keeps
  // mining whatever is currently active (or nothing) until the person
  // manually picks a campaign via mineCampaign().
  void setAutoMining(bool enabled) {
    autoMiningEnabled = enabled;
    _log.log('Auto-mining ${enabled ? "enabled" : "disabled"}',
        tag: 'MiningService');
    if (enabled) {
      _manualCampaign = null;
      _pickBestChannel();
    }
  }

  // Manually mine a specific campaign, bypassing priority/auto-selection.
  // Stays on it until the person picks another one or re-enables auto mode.
  Future<void> mineCampaign(DropCampaign campaign) async {
    autoMiningEnabled = false;
    _manualCampaign = campaign;
    _log.log('Manually selected campaign: ${campaign.name} (${campaign.gameName})',
        tag: 'MiningService');

    if (campaign.gameSlug.isEmpty) {
      _log.log('Campaign has no usable game slug, cannot find a channel',
          tag: 'MiningService');
      return;
    }

    try {
      final channels = await _channelService.fetchLiveChannels(
        campaign.gameSlug,
        campaign.gameId,
        campaign.gameName,
      );
      if (channels.isEmpty) {
        _log.log('No live channels found for "${campaign.gameName}"',
            tag: 'MiningService');
        activeChannel = null;
        _statusController.add(null);
        return;
      }
      channels.sort((a, b) => b.viewers.compareTo(a.viewers));
      activeChannel = channels.first;
      _log.log(
        'Now mining "${campaign.gameName}" on channel '
        '${activeChannel!.displayName} (${activeChannel!.viewers} viewers)',
        tag: 'MiningService',
      );
      _statusController.add(activeChannel);
      _ping();
    } catch (e) {
      _log.log('mineCampaign failed for "${campaign.gameName}": $e',
          tag: 'MiningService');
    }
  }

  Future<void> _pickBestChannel() async {
    if (!autoMiningEnabled) return;
    final priority = await _settings.loadPriority();
    final excluded = await _settings.loadExcludedGames();
    final sortMode = await _settings.loadSortMode();

    final eligible = _campaigns.where((c) =>
        c.isAccountConnected &&
        c.gameSlug.isNotEmpty &&
        !excluded.contains(c.gameId) &&
        (c.drops.isEmpty || c.drops.any((d) => !d.claimed)));

    if (eligible.isEmpty) {
      _log.log(
        'No eligible campaigns to mine (need: account linked + '
        'unclaimed drop + valid game + not excluded). '
        '${_campaigns.length} total campaigns, '
        '${_campaigns.where((c) => c.isAccountConnected).length} linked, '
        '${excluded.length} excluded.',
        tag: 'MiningService',
      );
      return;
    }

    final ordered = eligible.toList()
      ..sort((a, b) {
        // Manual priority list always wins when both games are ranked in it.
        final ai = priority.indexOf(a.gameId);
        final bi = priority.indexOf(b.gameId);
        if (ai != -1 || bi != -1) {
          final aRank = ai == -1 ? priority.length : ai;
          final bRank = bi == -1 ? priority.length : bi;
          if (aRank != bRank) return aRank.compareTo(bRank);
        }
        // Otherwise fall back to the chosen sort mode.
        switch (sortMode) {
          case SortMode.expiringSoonest:
            return a.endAt.compareTo(b.endAt);
          case SortMode.mostViewers:
            return 0; // resolved after fetching live viewer counts below
          case SortMode.alphabetical:
            return a.gameName.toLowerCase().compareTo(b.gameName.toLowerCase());
        }
      });

    if (sortMode == SortMode.mostViewers) {
      Channel? best;
      DropCampaign? bestCampaign;
      for (final campaign in ordered) {
        List<Channel> channels;
        try {
          channels = await _channelService.fetchLiveChannels(
            campaign.gameSlug, campaign.gameId, campaign.gameName);
        } catch (_) {
          continue;
        }
        if (channels.isEmpty) continue;
        channels.sort((a, b) => b.viewers.compareTo(a.viewers));
        if (best == null || channels.first.viewers > best.viewers) {
          best = channels.first;
          bestCampaign = campaign;
        }
      }
      if (best == null || bestCampaign == null) {
        _log.log('No live channels found across any eligible campaign',
            tag: 'MiningService');
        return;
      }
      if (activeChannel?.broadcastId != best.broadcastId) {
        activeChannel = best;
        _log.log(
          'Now mining "${bestCampaign.gameName}" on channel '
          '${best.displayName} (${best.viewers} viewers) — most-viewers mode',
          tag: 'MiningService',
        );
        _statusController.add(activeChannel);
        _ping();
      }
      return;
    }

    for (final campaign in ordered) {
      List<Channel> channels;
      try {
        channels = await _channelService.fetchLiveChannels(
          campaign.gameSlug,
          campaign.gameId,
          campaign.gameName,
        );
      } catch (e) {
        _log.log(
          'fetchLiveChannels failed for "${campaign.gameName}" '
          '(slug: ${campaign.gameSlug}): $e',
          tag: 'MiningService',
        );
        continue;
      }

      if (channels.isEmpty) {
        _log.log(
          'No live channels found for "${campaign.gameName}" '
          '(slug: ${campaign.gameSlug}), trying next campaign',
          tag: 'MiningService',
        );
        continue;
      }

      channels.sort((a, b) => b.viewers.compareTo(a.viewers));
      final candidate = channels.first;

      if (activeChannel?.broadcastId == candidate.broadcastId) return;

      activeChannel = candidate;
      _log.log(
        'Now mining "${campaign.gameName}" on channel '
        '${candidate.displayName} (${candidate.viewers} viewers)',
        tag: 'MiningService',
      );
      _statusController.add(activeChannel);

      // Send first ping immediately after switching channel.
      _ping();
      return;
    }

    _log.log(
      'Went through ${ordered.length} eligible campaigns but found no live '
      'channel to mine on any of them.',
      tag: 'MiningService',
    );
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
    } catch (e) {
      _log.log('Ping failed for ${ch.login}: $e', tag: 'MiningService');
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