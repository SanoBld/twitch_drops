import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/drop_campaign.dart';
import '../models/channel.dart';
import '../services/auth_service.dart';
import '../services/gql_service.dart';
import '../services/campaign_service.dart';
import '../services/mining_service.dart';
import '../widgets/campaign_card.dart';
import '../widgets/campaign_views.dart';
import '../widgets/update_dialog.dart';
import '../app_strings.dart';
import 'settings_screen.dart';
import 'filters_screen.dart';
import 'debug_screen.dart';
import '../main.dart' show trayService;

// Desktop feel: enable smooth mouse-wheel + trackpad scrolling with a light
// bounce, instead of the default abrupt/clamped desktop scroll physics.
class _DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

class HomeScreen extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onLogout;

  const HomeScreen({super.key, required this.auth, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final GqlService _gql;
  late final CampaignService _campaignService;
  late final MiningService _miningService;

  int _navIndex = 0;
  List<DropCampaign> _campaigns = [];
  Channel? _activeChannel;
  bool _loading = true;
  String? _error;
  bool _autoMining = true;
  bool _linkedOnly = true;
  CampaignViewMode _viewMode = CampaignViewMode.list;

  @override
  void initState() {
    super.initState();
    _gql = GqlService(widget.auth);
    _campaignService = CampaignService(_gql);
    _miningService = MiningService(_gql);
    _miningService.onChannelChanged.listen((ch) {
      if (mounted) setState(() => _activeChannel = ch);
      _pushTrayStatus(ch);
    });
    _miningService.onCampaignsUpdated.listen((_) {
      // Real Twitch-confirmed progress came in — refresh the list so
      // the progress bars on campaign cards reflect it immediately.
      if (mounted) setState(() {});
      _pushTrayStatus(_activeChannel);
    });

    // Rewire the tray menu's action buttons to the real implementations —
    // main.dart only has safe placeholder defaults since MiningService and
    // CampaignService don't exist yet at that point in startup.
    trayService.onStopMining = () {
      _miningService.stop();
      if (mounted) setState(() => _autoMining = false);
    };
    trayService.onToggleAutoMining = () => _toggleAutoMining(!_autoMining);
    trayService.onRefreshNow = _refresh;
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showUpdateDialogIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _miningService.dispose();
    super.dispose();
  }

  void _pushTrayStatus(Channel? ch) {
    if (ch == null) {
      trayService.updateMiningStatus(null);
      return;
    }
    // Find the current unclaimed drop for the game being mined, to show
    // its real progress in the tray tooltip/menu.
    double? progress;
    for (final c in _campaigns) {
      if (c.gameId == ch.gameId) {
        final drop = c.drops.where((d) => !d.claimed).cast<TimeBasedDrop?>().firstWhere(
              (d) => d != null,
              orElse: () => null,
            );
        if (drop != null) {
          progress = drop.progress;
          break;
        }
      }
    }
    trayService.updateMiningStatus(ch.displayName, gameName: ch.gameName, progress: progress);
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final campaigns = await _campaignService.fetchCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = campaigns;
        _loading = false;
      });
      if (campaigns.isNotEmpty) {
        await _miningService.start(campaigns);
      } else {
        _miningService.stop();
        trayService.updateMiningStatus(null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _campaigns = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _toggleAutoMining(bool value) {
    setState(() => _autoMining = value);
    _miningService.setAutoMining(value);
    trayService.setAutoMiningState(value);
  }

  void _mineCampaign(DropCampaign campaign) {
    setState(() => _autoMining = false);
    _miningService.mineCampaign(campaign);
  }

  List<DropCampaign> get _visibleCampaigns => _linkedOnly
      ? _campaigns.where((c) => c.isAccountConnected).toList()
      : _campaigns;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _DesktopScrollBehavior(),
      child: Scaffold(
        body: Row(
          children: [
            // ── Navigation Rail (compact, desktop-style) ────────────
            NavigationRail(
              selectedIndex: _navIndex,
              onDestinationSelected: (i) => setState(() => _navIndex = i),
              labelType: NavigationRailLabelType.all,
              minWidth: 64,
              leading: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 12),
                child: _AppLogo(),
              ),
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.bolt_outlined),
                  selectedIcon: const Icon(Icons.bolt),
                  label: Text(tr('nav_drops')),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: Text('Filtres'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(tr('nav_settings')),
                ),
              ],
            ),
            const VerticalDivider(width: 1),

            // ── Main content ─────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    navIndex: _navIndex,
                    loading: _loading,
                    onRefresh: _refresh,
                    onOpenDebug: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DebugScreen()),
                      );
                    },
                  ),

                  if (_navIndex == 0)
                    _MiningControlBar(
                      miningService: _miningService,
                      campaigns: _campaigns,
                      autoMining: _autoMining,
                      linkedOnly: _linkedOnly,
                      activeChannel: _activeChannel,
                      viewMode: _viewMode,
                      onAutoMiningChanged: _toggleAutoMining,
                      onLinkedOnlyChanged: (v) =>
                          setState(() => _linkedOnly = v),
                      onViewModeChanged: (m) => setState(() => _viewMode = m),
                    ),

                  Expanded(
                    child: IndexedStack(
                      index: _navIndex,
                      children: [
                        _DropsTab(
                          campaigns: _visibleCampaigns,
                          loading: _loading,
                          error: _error,
                          activeChannel: _activeChannel,
                          viewMode: _viewMode,
                          onRefresh: _refresh,
                          onMineCampaign: _mineCampaign,
                        ),
                        FiltersScreen(campaigns: _campaigns),
                        SettingsScreen(
                          auth: widget.auth,
                          campaigns: _campaigns,
                          onDisconnect: () {
                            _miningService.stop();
                            widget.onLogout();
                          },
                          onLanguageChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo ────────────────────────────────────────────────────────────────────

class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(Icons.bolt, color: cs.onPrimaryContainer, size: 18),
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int navIndex;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onOpenDebug;

  const _TopBar({
    required this.navIndex,
    required this.loading,
    required this.onRefresh,
    required this.onOpenDebug,
  });

  @override
  Widget build(BuildContext context) {
    final titles = [
      tr('title_drop_campaigns'),
      tr('title_filters'),
      tr('title_settings'),
    ];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Text(
            titles[navIndex],
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            iconSize: 18,
            tooltip: tr('debug_logs'),
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: onOpenDebug,
          ),
          if (navIndex == 0)
            loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    iconSize: 18,
                    tooltip: tr('refresh_campaigns'),
                    icon: const Icon(Icons.refresh_outlined),
                    onPressed: onRefresh,
                  ),
        ],
      ),
    );
  }
}

// ── Mining control bar ───────────────────────────────────────────────────────

class _MiningControlBar extends StatefulWidget {
  final MiningService miningService;
  final List<DropCampaign> campaigns;
  final bool autoMining;
  final bool linkedOnly;
  final Channel? activeChannel;
  final CampaignViewMode viewMode;
  final ValueChanged<bool> onAutoMiningChanged;
  final ValueChanged<bool> onLinkedOnlyChanged;
  final ValueChanged<CampaignViewMode> onViewModeChanged;

  const _MiningControlBar({
    required this.miningService,
    required this.campaigns,
    required this.autoMining,
    required this.linkedOnly,
    required this.activeChannel,
    required this.viewMode,
    required this.onAutoMiningChanged,
    required this.onLinkedOnlyChanged,
    required this.onViewModeChanged,
  });

  @override
  State<_MiningControlBar> createState() => _MiningControlBarState();
}

class _MiningControlBarState extends State<_MiningControlBar> {
  Timer? _ticker;
  bool _detailsOpen = false;

  @override
  void initState() {
    super.initState();
    // Tick every second just to refresh the "since/next" text below.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ms = widget.miningService;

    final now = DateTime.now();
    final sessionDuration =
        ms.miningStartedAt != null ? now.difference(ms.miningStartedAt!) : null;
    final sinceLastPing =
        ms.lastPingAt != null ? now.difference(ms.lastPingAt!) : null;
    final nextPingIn = sinceLastPing != null
        ? Duration(seconds: 60) - sinceLastPing
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.autoMining ? Icons.auto_mode : Icons.touch_app_outlined,
                size: 15,
                color: cs.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.autoMining ? tr('auto_mining') : tr('manual_mining'),
                style: tt.labelMedium,
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                    value: widget.autoMining, onChanged: widget.onAutoMiningChanged),
              ),
              if (widget.activeChannel != null) ...[
                const SizedBox(width: 4),
                _PulsingDotSmall(color: cs.secondary),
                const SizedBox(width: 4),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      widget.activeChannel!.displayName,
                      key: ValueKey(widget.activeChannel!.displayName),
                      style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              SegmentedButton<CampaignViewMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: CampaignViewMode.list,
                    icon: Icon(Icons.view_list_outlined, size: 16),
                    tooltip: 'Liste',
                  ),
                  ButtonSegment(
                    value: CampaignViewMode.poster,
                    icon: Icon(Icons.grid_view_outlined, size: 16),
                    tooltip: 'Affiches',
                  ),
                  ButtonSegment(
                    value: CampaignViewMode.compact,
                    icon: Icon(Icons.table_rows_outlined, size: 16),
                    tooltip: 'Tableau compact',
                  ),
                ],
                selected: {widget.viewMode},
                onSelectionChanged: (s) => widget.onViewModeChanged(s.first),
              ),
              const SizedBox(width: 8),
              FilterChip(
                visualDensity: VisualDensity.compact,
                label: Text(tr('linked_only')),
                selected: widget.linkedOnly,
                onSelected: widget.onLinkedOnlyChanged,
                avatar: Icon(widget.linkedOnly ? Icons.link : Icons.link_off, size: 14),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tr('mining_details'),
                iconSize: 18,
                icon: Icon(_detailsOpen ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => _detailsOpen = !_detailsOpen),
              ),
            ],
          ),
          if (widget.activeChannel != null && sessionDuration != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 21),
              child: Text(
                nextPingIn != null && !nextPingIn.isNegative
                    ? 'Mining depuis ${_fmtDuration(sessionDuration)} · prochain envoi dans ${nextPingIn.inSeconds}s'
                    : 'Mining depuis ${_fmtDuration(sessionDuration)} · envoi en cours…',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          if (_detailsOpen)
            _MiningDetailsPanel(
              miningService: widget.miningService,
              campaigns: widget.campaigns,
              activeChannel: widget.activeChannel,
            ),
        ],
      ),
    );
  }
}

// Expandable details panel: websocket status, campaign/drop progress with
// remaining time, and a list of live channels for the currently-mined game
// (fetched on demand, only while the panel is open).
class _MiningDetailsPanel extends StatefulWidget {
  final MiningService miningService;
  final List<DropCampaign> campaigns;
  final Channel? activeChannel;

  const _MiningDetailsPanel({
    required this.miningService,
    required this.campaigns,
    required this.activeChannel,
  });

  @override
  State<_MiningDetailsPanel> createState() => _MiningDetailsPanelState();
}

class _MiningDetailsPanelState extends State<_MiningDetailsPanel> {
  List<Channel>? _channels;
  bool _loadingChannels = false;
  StreamSubscription<bool>? _sub;
  bool _socketConnected = false;

  @override
  void initState() {
    super.initState();
    _socketConnected = widget.miningService.socketConnected;
    _sub = widget.miningService.onSocketConnectionChanged.listen((v) {
      if (mounted) setState(() => _socketConnected = v);
    });
    _loadChannels();
  }

  @override
  void didUpdateWidget(covariant _MiningDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChannel?.gameId != widget.activeChannel?.gameId) {
      _loadChannels();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() => _loadingChannels = true);
    final list = await widget.miningService.fetchLiveChannelsForActiveGame();
    if (mounted) setState(() {
      _channels = list;
      _loadingChannels = false;
    });
  }

  String _fmtRemaining(Duration d) {
    if (d.inMinutes <= 0) return '0m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}m';
  }

  DropCampaign? get _activeCampaign {
    final ch = widget.activeChannel;
    if (ch == null) return null;
    for (final c in widget.campaigns) {
      if (c.gameId == ch.gameId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final campaign = _activeCampaign;
    final drop = campaign?.drops.where((d) => !d.claimed).cast<TimeBasedDrop?>().firstWhere(
          (d) => d != null,
          orElse: () => null,
        );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Websocket status ─────────────────────────────────────
          Row(
            children: [
              Icon(_socketConnected ? Icons.wifi : Icons.wifi_off,
                  size: 14,
                  color: _socketConnected ? cs.secondary : cs.error),
              const SizedBox(width: 6),
              Text(
                _socketConnected ? tr('socket_connected') : tr('socket_disconnected'),
                style: tt.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Campaign / drop progress ──────────────────────────────
          if (campaign != null) ...[
            Text(campaign.gameName, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(campaign.name, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            if (drop != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text(drop.name, style: tt.labelSmall)),
                  Text(
                    '${(drop.progress * 100).toStringAsFixed(0)}% · '
                    '${_fmtRemaining(Duration(minutes: drop.remainingMinutes))} restantes',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: drop.progress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(cs.secondary),
                ),
              ),
            ],
          ] else
            Text(tr('nothing_mined'), style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),

          const SizedBox(height: 12),

          // ── Live channels ──────────────────────────────────────────
          Row(
            children: [
              Text(tr('live_channels'), style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (_loadingChannels)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 6),
          if (!_loadingChannels && (_channels == null || _channels!.isEmpty))
            Text('—', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _channels?.length ?? 0,
                itemBuilder: (_, i) {
                  final c = _channels![i];
                  final isActive = widget.activeChannel?.broadcastId == c.broadcastId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        if (isActive) Icon(Icons.play_arrow, size: 12, color: cs.secondary)
                        else const SizedBox(width: 12),
                        const SizedBox(width: 4),
                        Expanded(child: Text(c.displayName,
                            style: tt.labelSmall?.copyWith(
                                fontWeight: isActive ? FontWeight.w700 : null),
                            overflow: TextOverflow.ellipsis)),
                        Icon(Icons.remove_red_eye_outlined, size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${c.viewers}', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Drops tab ────────────────────────────────────────────────────────────────

class _DropsTab extends StatelessWidget {
  final List<DropCampaign> campaigns;
  final bool loading;
  final String? error;
  final Channel? activeChannel;
  final CampaignViewMode viewMode;
  final VoidCallback onRefresh;
  final ValueChanged<DropCampaign> onMineCampaign;

  const _DropsTab({
    required this.campaigns,
    required this.loading,
    required this.error,
    required this.activeChannel,
    required this.viewMode,
    required this.onRefresh,
    required this.onMineCampaign,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: cs.error),
              const SizedBox(height: 12),
              Text(tr('failed_to_load'), style: tt.titleSmall),
              const SizedBox(height: 6),
              Text(error!,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(tr('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (campaigns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 40, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(tr('no_campaigns_title'), style: tt.titleSmall),
              const SizedBox(height: 6),
              Text(
                tr('no_campaigns_body'),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(tr('check_again')),
              ),
            ],
          ),
        ),
      );
    }

    switch (viewMode) {
      case CampaignViewMode.poster:
        return PosterCampaignGrid(
          campaigns: campaigns,
          activeChannelGameId: activeChannel?.gameId,
          onMineCampaign: onMineCampaign,
        );
      case CampaignViewMode.compact:
        return CompactCampaignList(
          campaigns: campaigns,
          activeChannelGameId: activeChannel?.gameId,
          onMineCampaign: onMineCampaign,
        );
      case CampaignViewMode.list:
        return Scrollbar(
          thumbVisibility: true,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: campaigns.length,
            itemBuilder: (_, i) {
              final campaign = campaigns[i];
              return TweenAnimationBuilder<double>(
                key: ValueKey(campaign.id),
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 220 + (i.clamp(0, 12) * 25)),
                curve: Curves.easeOut,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 8),
                    child: child,
                  ),
                ),
                child: GestureDetector(
                  onTap: () => onMineCampaign(campaign),
                  child: CampaignCard(
                    campaign: campaign,
                    isActivelymining: activeChannel != null &&
                        campaign.gameId == activeChannel!.gameId,
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}

// Small breathing dot for "live" indicators in the top control bar.
class _PulsingDotSmall extends StatefulWidget {
  final Color color;
  const _PulsingDotSmall({required this.color});

  @override
  State<_PulsingDotSmall> createState() => _PulsingDotSmallState();
}

class _PulsingDotSmallState extends State<_PulsingDotSmall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.5 + 0.5 * t),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}