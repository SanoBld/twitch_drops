import 'package:flutter/material.dart';
import '../models/drop_campaign.dart';
import '../services/game_image_service.dart';
import '../services/mining_service.dart';
import '../models/channel.dart';

enum CampaignViewMode { list, poster, compact }

// Shared helper: overall progress across a campaign's unclaimed drops
// (average), used by the poster and compact views which show one number
// instead of a per-drop breakdown.
double _overallProgress(DropCampaign c) {
  final unclaimed = c.drops.where((d) => !d.claimed).toList();
  if (unclaimed.isEmpty) return c.drops.isEmpty ? 0 : 1.0;
  final total = unclaimed.fold<double>(0, (sum, d) => sum + d.progress);
  return total / unclaimed.length;
}

// ── Mode 2: Poster grid ──────────────────────────────────────────────────
// Big box art tiles, minimal text, a slim progress bar along the bottom.
// Right-click (or long-press) opens a details dialog with the full
// per-drop breakdown instead of cluttering the tile itself.
class PosterCampaignGrid extends StatelessWidget {
  final List<DropCampaign> campaigns;
  final Object? activeChannelGameId;
  final ValueChanged<DropCampaign> onMineCampaign;
  final MiningService miningService;

  const PosterCampaignGrid({
    super.key,
    required this.campaigns,
    required this.activeChannelGameId,
    required this.onMineCampaign,
    required this.miningService,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemCount: campaigns.length,
        itemBuilder: (_, i) {
          final c = campaigns[i];
          final isActive = c.gameId == activeChannelGameId;
          return _PosterTile(
            campaign: c,
            isActive: isActive,
            onTap: () => onMineCampaign(c),
            onDetails: () => showDialog(
              context: context,
              builder: (_) => ChannelPickerDialog(campaign: c, miningService: miningService),
            ),
          );
        },
      ),
    );
  }
}

class _PosterTile extends StatefulWidget {
  final DropCampaign campaign;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  const _PosterTile({
    required this.campaign,
    required this.isActive,
    required this.onTap,
    required this.onDetails,
  });

  @override
  State<_PosterTile> createState() => _PosterTileState();
}

class _PosterTileState extends State<_PosterTile> {
  bool _twitchFailed = false;
  String? _fallbackUrl;
  bool _fallbackRequested = false;
  bool _hovered = false;

  void _requestFallback() {
    if (_fallbackRequested) return;
    _fallbackRequested = true;
    GameImageService.instance
        .fetchFallbackImage(widget.campaign.gameName)
        .then((url) {
      if (mounted && url != null) setState(() => _fallbackUrl = url);
    });
  }

  Widget _art(ColorScheme cs) {
    final c = widget.campaign;
    if (c.boxArtUrl.isNotEmpty && !_twitchFailed) {
      return Image.network(
        c.boxArtUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _twitchFailed = true);
          });
          return Container(color: cs.surfaceContainerHighest);
        },
      );
    }
    if (_fallbackUrl != null) {
      return Image.network(_fallbackUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: cs.surfaceContainerHighest));
    }
    _requestFallback();
    return Container(
      color: cs.surfaceContainerHighest,
      child: SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = _overallProgress(widget.campaign);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (_) => widget.onDetails(),
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _art(cs),
                // Bottom gradient so the progress bar/text stay legible
                // over any artwork.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.campaign.gameName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 500),
                            builder: (context, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 4,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation(cs.secondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isActive)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: cs.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                if (!widget.campaign.isAccountConnected)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mode 3: Compact table ────────────────────────────────────────────────
// Dense single-line rows — built for scanning through 100+ campaigns
// quickly rather than admiring artwork.
class CompactCampaignList extends StatelessWidget {
  final List<DropCampaign> campaigns;
  final Object? activeChannelGameId;
  final ValueChanged<DropCampaign> onMineCampaign;
  final MiningService miningService;

  const CompactCampaignList({
    super.key,
    required this.campaigns,
    required this.activeChannelGameId,
    required this.onMineCampaign,
    required this.miningService,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scrollbar(
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: campaigns.length,
        itemBuilder: (_, i) {
          final c = campaigns[i];
          final isActive = c.gameId == activeChannelGameId;
          final progress = _overallProgress(c);
          final daysLeft = c.endAt.difference(DateTime.now()).inDays;

          return InkWell(
            onTap: () => onMineCampaign(c),
            onSecondaryTapDown: (_) => showDialog(
              context: context,
              builder: (_) => ChannelPickerDialog(campaign: c, miningService: miningService),
            ),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? cs.secondaryContainer.withValues(alpha: 0.4)
                    : null,
                border: Border(
                  bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
                ),
              ),
              child: Row(
                children: [
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SizedBox.shrink(),
                    ),
                  Expanded(
                    flex: 3,
                    child: Text(c.gameName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                  if (!c.isAccountConnected)
                    SizedBox.shrink(),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 70,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 5,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(cs.secondary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text('${(progress * 100).toStringAsFixed(0)}%',
                        style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      daysLeft <= 0 ? "aujourd'hui" : '${daysLeft}j',
                      textAlign: TextAlign.right,
                      style: tt.labelSmall?.copyWith(
                        color: daysLeft <= 3 ? cs.tertiary : cs.onSurfaceVariant,
                        fontWeight: daysLeft <= 3 ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Shared details dialog (used by poster + compact modes) ──────────────
class _CampaignDetailsDialog extends StatelessWidget {
  final DropCampaign campaign;
  const _CampaignDetailsDialog({required this.campaign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(campaign.gameName,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(campaign.name,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              ...campaign.drops.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(d.name,
                                    style: tt.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                            Text(
                              d.claimed
                                  ? 'Claimed'
                                  : '${(d.progress * 100).toStringAsFixed(0)}% · ${d.currentMinutes}/${d.requiredMinutes}m',
                              style: tt.labelSmall?.copyWith(
                                color: d.claimed ? cs.secondary : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: d.claimed ? 1 : d.progress,
                            minHeight: 5,
                            backgroundColor: cs.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(cs.secondary),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Right-click on a campaign: shows ONLY that game's live channels, with
// live viewer counts, and lets the user pick one manually.
class ChannelPickerDialog extends StatefulWidget {
  final DropCampaign campaign;
  final MiningService miningService;
  const ChannelPickerDialog({required this.campaign, required this.miningService});

  @override
  State<ChannelPickerDialog> createState() => ChannelPickerDialogState();
}

class ChannelPickerDialogState extends State<ChannelPickerDialog> {
  List<Channel>? _channels;

  @override
  void initState() {
    super.initState();
    widget.miningService.fetchLiveChannelsForCampaign(widget.campaign).then((c) {
      if (mounted) setState(() => _channels = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.campaign.gameName,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (_channels == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_channels!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Aucune chaîne en direct',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _channels!.length,
                    itemBuilder: (_, i) {
                      final c = _channels![i];
                      return ListTile(
                        dense: true,
                        title: Text(c.displayName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.shrink(),
                            const SizedBox(width: 4),
                            Text('${c.viewers}',
                                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                        onTap: () {
                          widget.miningService.mineChannel(widget.campaign, c);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}