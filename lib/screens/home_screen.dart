import 'package:flutter/material.dart';
import '../models/channel.dart';
import '../models/drop_campaign.dart';
import '../services/auth_service.dart';
import '../services/gql_service.dart';
import '../services/campaign_service.dart';
import '../services/mining_service.dart';
import '../services/autostart_service.dart';
import '../widgets/campaign_card.dart';
import '../widgets/update_dialog.dart';

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
  final _autostart = AutostartService();
  bool _autostartEnabled = false;
  List<DropCampaign> _campaigns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _gql = GqlService(widget.auth);
    _campaignService = CampaignService(_gql);
    _miningService = MiningService(_gql);
    _refresh();
    _autostart.isEnabled().then((v) {
      if (mounted) setState(() => _autostartEnabled = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showUpdateDialogIfNeeded(context);
    });
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
          IconButton(
            tooltip: _autostartEnabled
                ? 'Disable start with system'
                : 'Enable start with system',
            icon: Icon(_autostartEnabled ? Icons.power : Icons.power_off),
            onPressed: () async {
              if (_autostartEnabled) {
                await _autostart.disable();
              } else {
                await _autostart.enable();
              }
              if (mounted) {
                setState(() => _autostartEnabled = !_autostartEnabled);
              }
            },
          ),
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
