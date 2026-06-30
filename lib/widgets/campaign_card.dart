import 'package:flutter/material.dart';
import '../models/drop_campaign.dart';

class CampaignCard extends StatelessWidget {
  final DropCampaign campaign;
  const CampaignCard({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(campaign.gameName,
                style: Theme.of(context).textTheme.titleMedium),
            Text(campaign.name, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ...campaign.drops.map((d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(d.name)),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(value: d.progress),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
