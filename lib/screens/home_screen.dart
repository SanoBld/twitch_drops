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

  @override
  void initState() {
    super.initState();
    _gql = GqlService(widget.auth);
    _campaignService = CampaignService(_gql);
    _miningService = MiningService(_gql);
    _miningService.onChannelChanged.listen((ch) {
      if (mounted) setState(() => _activeChannel = ch);
      trayService.updateMiningStatus(ch?.displayName);
    });
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
                      autoMining: _autoMining,
                      linkedOnly: _linkedOnly,
                      activeChannel: _activeChannel,
                      onAutoMiningChanged: _toggleAutoMining,
                      onLinkedOnlyChanged: (v) =>
                          setState(() => _linkedOnly = v),
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
  final bool autoMining;
  final bool linkedOnly;
  final Channel? activeChannel;
  final ValueChanged<bool> onAutoMiningChanged;
  final ValueChanged<bool> onLinkedOnlyChanged;

  const _MiningControlBar({
    required this.miningService,
    required this.autoMining,
    required this.linkedOnly,
    required this.activeChannel,
    required this.onAutoMiningChanged,
    required this.onLinkedOnlyChanged,
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
                color: cs.primary,
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
                Icon(Icons.circle, size: 7, color: cs.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.activeChannel!.displayName,
                    style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
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
  final VoidCallback onRefresh;
  final ValueChanged<DropCampaign> onMineCampaign;

  const _DropsTab({
    required this.campaigns,
    required this.loading,
    required this.error,
    required this.activeChannel,
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

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: campaigns.length,
        itemBuilder: (_, i) {
          final campaign = campaigns[i];
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onMineCampaign(campaign),
            child: CampaignCard(
              campaign: campaign,
              isActivelymining: activeChannel != null &&
                  campaign.gameId == activeChannel!.gameId,
            ),
          );
        },
      ),
    );
  }
}