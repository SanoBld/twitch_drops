import 'dart:async';
import 'dart:convert';
import '../models/channel.dart';
import '../models/drop_campaign.dart';
import 'gql_service.dart';
import 'channel_service.dart';
import 'settings_service.dart';
import 'log_service.dart';
import 'socket_service.dart';

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

  // Exposed for the UI so it can show "mining since..." / "next update in...".
  DateTime? miningStartedAt;
  DateTime? lastPingAt;

  final _statusController = StreamController<Channel?>.broadcast();
  Stream<Channel?> get onChannelChanged => _statusController.stream;

  // Fires whenever a drop's progress changes (from a real Twitch pubsub
  // confirmation), so the UI can rebuild the campaign list to show it.
  final _campaignsUpdatedController = StreamController<void>.broadcast();
  Stream<void> get onCampaignsUpdated => _campaignsUpdatedController.stream;

  TwitchSocketService? _socket;

  bool get socketConnected => _socket?.connected ?? false;
  Stream<bool> get onSocketConnectionChanged =>
      _socket?.onConnectionChanged ?? const Stream.empty();

  List<DropCampaign> get campaigns => _campaigns;

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

    // Connect to Twitch's real-time drop-progress feed. This is the SAME
    // mechanism the reference TwitchDropsMiner app uses — Twitch pushes
    // authoritative "drop-progress" / "drop-claim" events here, so the
    // progress shown in the app reflects what Twitch has actually
    // registered, not a local guess.
    if (_userId.isNotEmpty && _socket == null) {
      _socket = TwitchSocketService(_handleSocketEvent);
      _socket!.connect(
        ['user-drop-events.$_userId'],
        authToken: gql.auth.token,
      );
      _log.log('Connected to user-drop-events.$_userId for real progress updates',
          tag: 'MiningService');
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

  // Handles raw PubSub frames. Twitch wraps actual events as:
  // { type: "MESSAGE", data: { topic: "...", message: "<json string>" } }
  // where the inner "message" is itself JSON-encoded and needs decoding.
  void _handleSocketEvent(Map<String, dynamic> frame) {
    if (frame['type'] != 'MESSAGE') return;
    final topic = frame['data']?['topic']?.toString() ?? '';
    if (!topic.startsWith('user-drop-events')) return;

    Map<String, dynamic> inner;
    try {
      inner = jsonDecode(frame['data']['message'] as String) as Map<String, dynamic>;
    } catch (e) {
      _log.log('Failed to parse drop-event message: $e', tag: 'MiningService');
      return;
    }

    final eventType = inner['type']?.toString() ?? '';
    final data = inner['data'] as Map<String, dynamic>?;
    if (data == null) return;

    if (eventType == 'drop-progress') {
      final dropId = data['drop_id']?.toString();
      final current = data['current_progress_min'] as int?;
      final required = data['required_progress_min'] as int?;
      if (dropId == null || current == null) return;
      _log.log(
        'Real progress update from Twitch: drop $dropId → $current'
        '${required != null ? '/$required' : ''} min',
        tag: 'MiningService',
      );
      _updateDropProgress(dropId, currentMinutes: current);
    } else if (eventType == 'drop-claim') {
      final dropId = data['drop_id']?.toString();
      final dropInstanceId = data['drop_instance_id']?.toString();
      if (dropId == null) return;
      _log.log('Drop $dropId is ready to claim (per Twitch) — claiming automatically',
          tag: 'MiningService');
      _updateDropProgress(dropId, claimed: true);
      if (dropInstanceId != null) {
        gql.claimDropReward(dropInstanceId).then((ok) {
          _log.log(
            ok
                ? 'Successfully claimed drop $dropId'
                : 'Failed to auto-claim drop $dropId (will still show as complete; '
                    'claim it manually on twitch.tv/drops/inventory if needed)',
            tag: 'MiningService',
          );
        });
      }
    }
  }

  void _updateDropProgress(String dropId, {int? currentMinutes, bool? claimed}) {
    var changed = false;
    for (final campaign in _campaigns) {
      for (final drop in campaign.drops) {
        if (drop.id == dropId) {
          if (currentMinutes != null) drop.currentMinutes = currentMinutes;
          if (claimed != null) drop.claimed = claimed;
          changed = true;
        }
      }
    }
    if (changed) {
      _campaignsUpdatedController.add(null);
    }
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
    // Don't restart the session if we're already mining this exact
    // campaign — switching channels resets Twitch's per-stream watch
    // timer, so re-selecting the same one should be a no-op.
    if (_manualCampaign?.id == campaign.id && activeChannel != null) {
      _log.log('Already mining "${campaign.name}", ignoring re-tap',
          tag: 'MiningService');
      return;
    }

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
      final candidate = channels.first;
      if (activeChannel?.broadcastId == candidate.broadcastId) {
        // Same underlying stream — don't reset the session timer.
        return;
      }
      activeChannel = candidate;
      miningStartedAt = DateTime.now();
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

  // Fetches the live channels list (with viewer counts) for whichever
  // campaign is currently being mined, for on-demand display in the UI's
  // details panel. Returns an empty list if nothing is being mined.
  // Fetches live channels for ANY campaign (not just the active one), used
  // by the right-click "pick a channel" dialog.
  Future<List<Channel>> fetchLiveChannelsForCampaign(DropCampaign campaign) async {
    if (campaign.gameSlug.isEmpty) return [];
    try {
      final channels = await _channelService.fetchLiveChannels(
          campaign.gameSlug, campaign.gameId, campaign.gameName);
      channels.sort((a, b) => b.viewers.compareTo(a.viewers));
      return channels;
    } catch (e) {
      _log.log('fetchLiveChannelsForCampaign failed: $e', tag: 'MiningService');
      return [];
    }
  }

  // Manually pin a specific channel (picked by the user), bypassing
  // auto-selection entirely.
  Future<void> mineChannel(DropCampaign campaign, Channel channel) async {
    autoMiningEnabled = false;
    _manualCampaign = campaign;
    if (activeChannel?.broadcastId == channel.broadcastId) return;
    activeChannel = channel;
    miningStartedAt = DateTime.now();
    _log.log('Manually pinned channel ${channel.displayName} (${campaign.gameName})',
        tag: 'MiningService');
    _statusController.add(activeChannel);
    _ping();
  }

  Future<List<Channel>> fetchLiveChannelsForActiveGame() async {
    final ch = activeChannel;
    if (ch == null) return [];
    final campaign = _campaigns.cast<DropCampaign?>().firstWhere(
          (c) => c?.gameId == ch.gameId,
          orElse: () => null,
        );
    if (campaign == null || campaign.gameSlug.isEmpty) return [];
    try {
      final channels = await _channelService.fetchLiveChannels(
          campaign.gameSlug, campaign.gameId, campaign.gameName);
      channels.sort((a, b) => b.viewers.compareTo(a.viewers));
      return channels;
    } catch (e) {
      _log.log('fetchLiveChannelsForActiveGame failed: $e', tag: 'MiningService');
      return [];
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
        miningStartedAt = DateTime.now();
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
      miningStartedAt = DateTime.now();
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
      lastPingAt = DateTime.now();
    } catch (e) {
      _log.log('Ping failed for ${ch.login}: $e', tag: 'MiningService');
      // Failed ping likely means channel went offline; re-pick next cycle.
    }
  }

  void stop() {
    _pingTimer?.cancel();
    _switchCheckTimer?.cancel();
    _socket?.disconnect();
    _socket = null;
    activeChannel = null;
    miningStartedAt = null;
    lastPingAt = null;
    _statusController.add(null);
  }

  void dispose() {
    stop();
    _statusController.close();
    _campaignsUpdatedController.close();
  }
}