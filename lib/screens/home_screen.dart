import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/drop_campaign.dart';
import '../models/channel.dart';
import '../services/auth_service.dart';
import '../services/gql_service.dart';
import '../services/campaign_service.dart';
import '../services/mining_service.dart';
import '../services/settings_service.dart';
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
  String? _statusBanner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _gql = GqlService(widget.auth);
    _campaignService = CampaignService(_gql);
    _miningService = MiningService(_gql);
    _miningService.onChannelChanged.listen((ch) {
      if (mounted) setState(() => _activeChannel = ch);
      _pushTrayStatus(ch);
      _showBanner(ch != null
          ? 'Changement vers ${ch.displayName} (${ch.gameName})…'
          : 'Minage arrêté');
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
    SettingsService().getMinimizeToTray().then((v) => trayService.minimizeToTrayEnabled = v);
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showUpdateDialogIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _miningService.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _showBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _statusBanner = text);
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _statusBanner = null);
    });
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

                  if (_statusBanner != null) _StatusBanner(text: _statusBanner!),

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
                          miningService: _miningService,
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

// Thin, auto-dismissing banner shown at the top on state changes (e.g.
// "changement vers <chaîne>…") so something visibly happens.
class _StatusBanner extends StatelessWidget {
  final String text;
  const _StatusBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey(text),
      width: double.infinity,
      color: cs.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.onSecondaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

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
  final MiningService miningService;

  const _DropsTab({
    required this.campaigns,
    required this.loading,
    required this.error,
    required this.activeChannel,
    required this.viewMode,
    required this.onRefresh,
    required this.onMineCampaign,
    required this.miningService,
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

    final activeCampaign = activeChannel == null
        ? null
        : campaigns.cast<DropCampaign?>().firstWhere(
            (c) => c?.gameId == activeChannel!.gameId,
            orElse: () => null,
          );
    final restCampaigns =
        activeCampaign == null ? campaigns : campaigns.where((c) => c.id != activeCampaign.id).toList();

    return Column(
      children: [
        if (activeCampaign != null)
          _ActiveCampaignHero(
            campaign: activeCampaign,
            activeChannel: activeChannel!,
            miningService: miningService,
            totalCampaigns: campaigns.length,
          ),
        Expanded(child: _buildCampaignsView(context, restCampaigns)),
      ],
    );
  }

  Widget _buildCampaignsView(BuildContext context, List<DropCampaign> campaigns) {
    switch (viewMode) {
      case CampaignViewMode.poster:
        return PosterCampaignGrid(
          campaigns: campaigns,
          activeChannelGameId: activeChannel?.gameId,
          onMineCampaign: onMineCampaign,
          miningService: miningService,
        );
      case CampaignViewMode.compact:
        return CompactCampaignList(
          campaigns: campaigns,
          activeChannelGameId: activeChannel?.gameId,
          onMineCampaign: onMineCampaign,
          miningService: miningService,
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
                  onSecondaryTapDown: (_) => showDialog(
                    context: context,
                    builder: (_) => ChannelPickerDialog(
                      campaign: campaign,
                      miningService: miningService,
                    ),
                  ),
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

// Pinned card for the campaign currently being mined: game on the left,
// full details (drops with progress + reward image, live channels with
// viewer counts, a channel-picker button) on the right — or stacked below
// on narrow windows.
class _ActiveCampaignHero extends StatefulWidget {
  final DropCampaign campaign;
  final Channel activeChannel;
  final MiningService miningService;
  final int totalCampaigns;

  const _ActiveCampaignHero({
    required this.campaign,
    required this.activeChannel,
    required this.miningService,
    required this.totalCampaigns,
  });

  @override
  State<_ActiveCampaignHero> createState() => _ActiveCampaignHeroState();
}

class _ActiveCampaignHeroState extends State<_ActiveCampaignHero> {
  List<Channel>? _channels;
  bool _loadingChannels = false;
  StreamSubscription<bool>? _sub;
  bool _socketConnected = false;
  bool _expanded = false;

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
  void didUpdateWidget(covariant _ActiveCampaignHero old) {
    super.didUpdateWidget(old);
    if (old.campaign.id != widget.campaign.id) _loadChannels();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() => _loadingChannels = true);
    final list = await widget.miningService.fetchLiveChannelsForCampaign(widget.campaign);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final campaign = widget.campaign;

    final header = Row(
      children: [
        if (campaign.boxArtUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(campaign.boxArtUrl, width: 44, height: 58, fit: BoxFit.cover),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _PulsingDotSmall(color: cs.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(campaign.gameName,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              Text(campaign.name, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text('${widget.activeChannel.displayName} · ${widget.activeChannel.viewers} viewers',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton(
          tooltip: _expanded ? 'Réduire' : "Voir tous les drops et l'état",
          icon: Icon(_expanded ? Icons.remove_circle_outline : Icons.add_circle_outline),
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
      ],
    );

    final drops = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Drops disponibles', style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final d in campaign.drops) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(d.imageUrl, width: 36, height: 36, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(d.name, style: tt.bodySmall)),
                        if (d.claimed)
                          Text('Récupéré', style: tt.labelSmall?.copyWith(color: cs.secondary))
                        else
                          Text(
                            '${(d.progress * 100).toStringAsFixed(0)}% · '
                            '${_fmtRemaining(Duration(minutes: d.remainingMinutes))} restantes',
                            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: d.claimed ? 1 : d.progress,
                        minHeight: 5,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(cs.secondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );

    final status = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_socketConnected ? Icons.wifi : Icons.wifi_off,
            size: 13, color: _socketConnected ? cs.secondary : cs.error),
        const SizedBox(width: 5),
        Text(_socketConnected ? tr('socket_connected') : tr('socket_disconnected'),
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(width: 14),
        Icon(Icons.inventory_2_outlined, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 5),
        Text('${widget.totalCampaigns} campagnes chargées',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );

    final channelsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(tr('live_channels'), style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (_loadingChannels)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            const Spacer(),
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ChannelPickerDialog(campaign: campaign, miningService: widget.miningService),
              ),
              child: const Text('Changer de chaîne'),
            ),
          ],
        ),
        if (!_loadingChannels && (_channels == null || _channels!.isEmpty))
          Text('—', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant))
        else
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final c in (_channels ?? []))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.activeChannel.broadcastId == c.broadcastId)
                      Icon(Icons.play_arrow, size: 12, color: cs.secondary),
                    const SizedBox(width: 2),
                    Text(c.displayName,
                        style: tt.labelSmall?.copyWith(
                            fontWeight: widget.activeChannel.broadcastId == c.broadcastId
                                ? FontWeight.w700
                                : null)),
                    const SizedBox(width: 4),
                    Icon(Icons.remove_red_eye_outlined, size: 11, color: cs.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text('${c.viewers}', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
            ],
          ),
      ],
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.secondary, width: 1.2),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            if (_expanded) ...[
              const SizedBox(height: 14),
              status,
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 560
                    ? drops
                    : Align(alignment: Alignment.topLeft, child: drops),
              ),
              const SizedBox(height: 14),
              channelsSection,
            ],
          ],
        ),
      ),
    );
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