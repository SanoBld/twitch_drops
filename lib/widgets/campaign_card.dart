import 'package:flutter/material.dart';
import '../models/drop_campaign.dart';

class CampaignCard extends StatelessWidget {
  final DropCampaign campaign;
  final bool isActivelymining;

  const CampaignCard({
    super.key,
    required this.campaign,
    this.isActivelymining = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final daysLeft = campaign.endAt.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActivelymining
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActivelymining) ...[
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
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...campaign.drops.map((d) => _DropRow(drop: d)),
          ],
        ),
      ),
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
                  Icon(Icons.check_circle_outline,
                      size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Text('Claimed',
                      style: tt.labelSmall?.copyWith(color: cs.primary)),
                ])
              else
                Text(
                  '${drop.currentMinutes}m / ${drop.requiredMinutes}m',
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
