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
  bool _hovered = false;

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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        transform: Matrix4.identity()..scale(_hovered ? 1.006 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.isActivelymining
              ? cs.secondaryContainer.withValues(alpha: 0.55)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: widget.isActivelymining
              ? Border.all(color: cs.secondary, width: 1.4)
              : Border.all(color: Colors.transparent),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
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
                              _PulsingDot(color: cs.secondary),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(campaign.gameName,
                                  style: tt.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (!campaign.isAccountConnected) ...[
                              const SizedBox(width: 6),
                              SizedBox.shrink(),
                            ],
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: daysLeft <= 3
                                    ? cs.tertiaryContainer
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
                                  color: daysLeft <= 3
                                      ? cs.onTertiaryContainer
                                      : null,
                                  fontWeight:
                                      daysLeft <= 3 ? FontWeight.w600 : null,
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
      ),
    );
  }

  Widget _buildArt(DropCampaign campaign, ColorScheme cs) {
    if (campaign.boxArtUrl.isNotEmpty && !_twitchImageFailed) {
      return Image.network(
        campaign.boxArtUrl,
        width: 40,
        height: 53,
        fit: BoxFit.cover,
        errorBuilder: (_, error, ___) {
          // ignore: avoid_print
          print('[CampaignCard] Twitch image failed (${campaign.boxArtUrl}): $error');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _twitchImageFailed = true);
          });
          return _fallbackArt(cs);
        },
      );
    }
    if (_fallbackUrl != null) {
      return Image.network(
        _fallbackUrl!,
        width: 40,
        height: 53,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackArt(cs),
      );
    }
    _requestFallback();
    return _fallbackArt(cs);
  }

  Widget _fallbackArt(ColorScheme cs) => Container(
        width: 40,
        height: 53,
        color: cs.surfaceContainerHighest,
        child: SizedBox.shrink(),
      );
}

// A soft breathing dot to mark "actively mining" — subtle organic motion
// instead of a static indicator.
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.5 + 0.5 * t),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
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
                  SizedBox.shrink(),
                  const SizedBox(width: 4),
                  Text('Claimed',
                      style: tt.labelSmall?.copyWith(
                          color: cs.secondary, fontWeight: FontWeight.w600)),
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
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: drop.claimed ? 1.0 : drop.progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  drop.claimed ? cs.secondary.withValues(alpha: 0.6) : cs.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}