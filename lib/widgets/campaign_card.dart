import 'package:flutter/material.dart';
import '../models/drop_campaign.dart';
import '../services/game_image_service.dart';

class CampaignCard extends StatefulWidget {
  final DropCampaign campaign;
  final bool isActivelymining;

  const CampaignCard({
    super.key,
    required this.campaign,
    this.isActivelymining = false,
  });

  @override
  State<CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends State<CampaignCard> {
  bool _twitchImageFailed = false;
  String? _fallbackUrl;
  bool _fallbackRequested = false;

  void _requestFallback() {
    if (_fallbackRequested) return;
    _fallbackRequested = true;
    GameImageService.instance.fetchFallbackImage(widget.campaign.gameName).then((url) {
      if (mounted && url != null) setState(() => _fallbackUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final campaign = widget.campaign;
    final daysLeft = campaign.endAt.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.isActivelymining
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game box art — Twitch first, external fallback if that fails.
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildArt(campaign, cs),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.isActivelymining) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(campaign.gameName,
                                style: tt.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (!campaign.isAccountConnected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.link_off,
                                size: 14,
                                color: cs.error.withValues(alpha: 0.7)),
                          ],
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: daysLeft <= 3
                                  ? cs.errorContainer
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              daysLeft <= 0
                                  ? 'Ends today'
                                  : daysLeft == 1
                                      ? '1 day left'
                                      : '$daysLeft days left',
                              style: tt.labelSmall?.copyWith(
                                color: daysLeft <= 3 ? cs.onErrorContainer : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(campaign.name,
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...campaign.drops.map((d) => _DropRow(drop: d)),
          ],
        ),
      ),
    );
  }

  Widget _buildArt(DropCampaign campaign, ColorScheme cs) {
    // 1) Try Twitch's own box art first.
    if (campaign.boxArtUrl.isNotEmpty && !_twitchImageFailed) {
      return Image.network(
        campaign.boxArtUrl,
        width: 40,
        height: 53,
        fit: BoxFit.cover,
        errorBuilder: (_, error, ___) {
          // ignore: avoid_print
          print('[CampaignCard] Twitch image failed (${campaign.boxArtUrl}): $error');
          // Schedule a rebuild using the Steam fallback instead.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _twitchImageFailed = true);
          });
          return _fallbackArt(cs);
        },
      );
    }

    // 2) Twitch failed or had no URL — try the Steam fallback.
    if (_fallbackUrl != null) {
      return Image.network(
        _fallbackUrl!,
        width: 40,
        height: 53,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackArt(cs),
      );
    }

    // 3) Nothing yet — kick off the fallback fetch and show a placeholder
    // in the meantime.
    _requestFallback();
    return _fallbackArt(cs);
  }

  Widget _fallbackArt(ColorScheme cs) => Container(
        width: 40,
        height: 53,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.videogame_asset_outlined,
            size: 20, color: cs.onSurfaceVariant),
      );
}

class _DropRow extends StatelessWidget {
  final TimeBasedDrop drop;
  const _DropRow({required this.drop});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(drop.name,
                    style: tt.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              if (drop.claimed)
                Row(children: [
                  Icon(Icons.check_circle_outline,
                      size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Text('Claimed',
                      style: tt.labelSmall?.copyWith(color: cs.primary)),
                ])
              else
                Text(
                  '${(drop.progress * 100).toStringAsFixed(0)}% · '
                  '${drop.currentMinutes}/${drop.requiredMinutes}m · '
                  '${drop.remainingMinutes}m restantes',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: drop.claimed ? 1.0 : drop.progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                  drop.claimed ? cs.primary.withValues(alpha: 0.5) : cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}