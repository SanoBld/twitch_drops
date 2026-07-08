import 'package:flutter/material.dart';
import '../models/drop_campaign.dart';
import '../services/settings_service.dart';

class PriorityScreen extends StatefulWidget {
  final List<DropCampaign> campaigns;
  const PriorityScreen({super.key, required this.campaigns});

  @override
  State<PriorityScreen> createState() => _PriorityScreenState();
}

class _PriorityScreenState extends State<PriorityScreen> {
  final _settings = SettingsService();
  List<String> _order = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await _settings.loadPriority();
    final allGameIds = widget.campaigns.map((c) => c.gameId).toSet();
    // Keep saved order first, then add any new games not yet ranked.
    final order = [
      ...saved.where(allGameIds.contains),
      ...allGameIds.where((id) => !saved.contains(id)),
    ];
    setState(() {
      _order = order;
      _loading = false;
    });
  }

  String _nameFor(String gameId) {
    final c = widget.campaigns.firstWhere(
      (c) => c.gameId == gameId,
      orElse: () => widget.campaigns.first,
    );
    return c.gameName;
  }

  Future<void> _save() async {
    await _settings.savePriority(_order);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game priority')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order.isEmpty
              ? const Center(child: Text('No active campaigns to rank yet'))
              : ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _order.removeAt(oldIndex);
                      _order.insert(newIndex, item);
                    });
                    _save();
                  },
                  children: [
                    for (var i = 0; i < _order.length; i++)
                      ListTile(
                        key: ValueKey(_order[i]),
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(_nameFor(_order[i])),
                        trailing: const SizedBox.shrink(),
                      ),
                  ],
                ),
    );
  }
}