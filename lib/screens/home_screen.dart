import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/drop_campaign.dart';
import '../services/auth_service.dart';
import '../services/gql_service.dart';
import '../services/campaign_service.dart';
import '../services/mining_service.dart';
import '../widgets/campaign_card.dart';

class HomeScreen extends StatefulWidget {
  final AuthService auth;
  const HomeScreen({super.key, required this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final GqlService _gql;
  late final CampaignService _campaignService;
  late final MiningService _miningService;
  List<DropCampaign> _campaigns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _gql = GqlService(widget.auth);
    _campaignService = CampaignService(_gql);
    _miningService = MiningService(_gql);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _campaigns = await _campaignService.fetchCampaigns();
    } catch (_) {
      _campaigns = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drops'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _campaigns.isEmpty
              ? const Center(child: Text('No active campaign found'))
              : Column(
                  children: [
                    if (_miningService.activeChannel != null)
                      Container(
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Mining: ${_miningService.activeChannel!.displayName}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        children: _campaigns
                            .map((c) => CampaignCard(campaign: c))
                            .toList(),
                      ),
                    ),
                  ],
                ),
    );
  }
}
