import 'package:flutter/material.dart';
import '../models/drop_campaign.dart';
import '../models/channel.dart';
import '../services/auth_service.dart';
import '../services/gql_service.dart';
import '../services/campaign_service.dart';
import '../services/mining_service.dart';
import '../widgets/campaign_card.dart';
import '../widgets/update_dialog.dart';
import 'settings_screen.dart';
import 'debug_screen.dart';
import '../main.dart' show trayService;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Navigation Rail ──────────────────────────────────────
          NavigationRail(
            selectedIndex: _navIndex,
            onDestinationSelected: (i) => setState(() => _navIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              child: _AppLogo(),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.bolt_outlined),
                selectedIcon: Icon(Icons.bolt),
                label: Text('Drops'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),

          // ── Main content ─────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
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

                // Mining banner (only on Drops tab)
                if (_navIndex == 0 && _activeChannel != null)
                  _MiningBanner(channel: _activeChannel!),

                // Page content
                Expanded(
                  child: IndexedStack(
                    index: _navIndex,
                    children: [
                      _DropsTab(
                        campaigns: _campaigns,
                        loading: _loading,
                        error: _error,
                        activeChannel: _activeChannel,
                        onRefresh: _refresh,
                      ),
                      SettingsScreen(
                        auth: widget.auth,
                        campaigns: _campaigns,
                        onDisconnect: () {
                          _miningService.stop();
                          widget.onLogout();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(Icons.bolt, color: cs.onPrimaryContainer, size: 22),
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
    const titles = ['Drop campaigns', 'Settings'];
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            titles[navIndex],
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Debug logs',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: onOpenDebug,
          ),
          if (navIndex == 0)
            loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'Refresh campaigns',
                    icon: const Icon(Icons.refresh_outlined),
                    onPressed: onRefresh,
                  ),
        ],
      ),
    );
  }
}

// ── Mining banner ────────────────────────────────────────────────────────────

class _MiningBanner extends StatelessWidget {
  final Channel channel;
  const _MiningBanner({required this.channel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.bolt, size: 18, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: 'Mining ',
                    style: tt.bodyMedium
                        ?.copyWith(color: cs.onPrimaryContainer)),
                TextSpan(
                    text: channel.displayName,
                    style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer)),
                if (channel.gameName.isNotEmpty)
                  TextSpan(
                      text: ' · ${channel.gameName}',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onPrimaryContainer)),
              ]),
            ),
          ),
          if (channel.viewers > 0)
            Row(children: [
              Icon(Icons.people_outline,
                  size: 14, color: cs.onPrimaryContainer),
              const SizedBox(width: 4),
              Text(
                _formatViewers(channel.viewers),
                style: tt.labelSmall
                    ?.copyWith(color: cs.onPrimaryContainer),
              ),
            ]),
        ],
      ),
    );
  }

  String _formatViewers(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toString();
  }
}

// ── Drops tab ────────────────────────────────────────────────────────────────

class _DropsTab extends StatelessWidget {
  final List<DropCampaign> campaigns;
  final bool loading;
  final String? error;
  final Channel? activeChannel;
  final VoidCallback onRefresh;

  const _DropsTab({
    required this.campaigns,
    required this.loading,
    required this.error,
    required this.activeChannel,
    required this.onRefresh,
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
              Icon(Icons.cloud_off_outlined, size: 48, color: cs.error),
              const SizedBox(height: 16),
              Text('Failed to load campaigns',
                  style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(error!,
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
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
              Icon(Icons.inbox_outlined, size: 48,
                  color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('No active drop campaigns',
                  style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Make sure:\n'
                '\u2022 Your Twitch account is linked to game accounts on twitch.tv/drops/campaigns\n'
                '\u2022 There are active drop campaigns for linked games\n'
                '\u2022 The account has not already claimed all drops\n\n'
                'Tap the bug icon (top right) to see the debug logs.',
                style:
                    tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Check again'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: campaigns.length,
      itemBuilder: (_, i) => CampaignCard(
        campaign: campaigns[i],
        isActivelymining:
            activeChannel != null &&
            campaigns[i].gameId == activeChannel!.gameId,
      ),
    );
  }
}