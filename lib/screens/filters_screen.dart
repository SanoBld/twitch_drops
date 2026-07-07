import 'package:flutter/material.dart';
import '../models/drop_campaign.dart';
import '../services/settings_service.dart';
import '../app_strings.dart';

class FiltersScreen extends StatefulWidget {
  final List<DropCampaign> campaigns;
  const FiltersScreen({super.key, required this.campaigns});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  final _settings = SettingsService();
  final _searchController = TextEditingController();
  String _query = '';

  bool _loading = true;
  List<String> _priorityOrder = [];
  Set<String> _excluded = {};
  SortMode _sortMode = SortMode.expiringSoonest;
  final _prioritySearchController = TextEditingController();
  String _priorityQuery = '';

  // Computed on demand instead of cached once in initState: widget.campaigns
  // is empty on first build (campaigns load async), so caching it there
  // froze search on a permanently-empty list.
  Map<String, String> get _games => {
        for (final c in widget.campaigns) c.gameId: c.gameName,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FiltersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.campaigns.length != widget.campaigns.length) _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _prioritySearchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> get _filteredGames {
    final entries = _games.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    if (_query.isEmpty) return entries;
    final q = _query.toLowerCase();
    return entries.where((e) => e.value.toLowerCase().contains(q)).toList();
  }

  Future<void> _load() async {
    final priority = await _settings.loadPriority();
    final excluded = await _settings.loadExcludedGames();
    final sortMode = await _settings.loadSortMode();

    final allIds = _games.keys.toSet();
    final order = [
      ...priority.where(allIds.contains),
      ...allIds.where((id) => !priority.contains(id)),
    ];

    setState(() {
      _priorityOrder = order;
      _excluded = excluded;
      _sortMode = sortMode;
      _loading = false;
    });
  }

  Future<void> _savePriority() => _settings.savePriority(_priorityOrder);
  Future<void> _saveExcluded() => _settings.saveExcludedGames(_excluded);
  Future<void> _saveSortMode(SortMode m) async {
    setState(() => _sortMode = m);
    await _settings.saveSortMode(m);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('title_filters'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr('title_filters'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // ── Sort mode ────────────────────────────────────────────
          _SectionHeader(title: tr('sort_by')),
          Card(
            child: Column(
              children: [
                RadioListTile<SortMode>(
                  title: Text(tr('sort_expiring_soon')),
                  value: SortMode.expiringSoonest,
                  groupValue: _sortMode,
                  onChanged: (v) => _saveSortMode(v!),
                ),
                RadioListTile<SortMode>(
                  title: Text(tr('sort_most_viewers')),
                  value: SortMode.mostViewers,
                  groupValue: _sortMode,
                  onChanged: (v) => _saveSortMode(v!),
                ),
                RadioListTile<SortMode>(
                  title: Text(tr('sort_alphabetical')),
                  value: SortMode.alphabetical,
                  groupValue: _sortMode,
                  onChanged: (v) => _saveSortMode(v!),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Priority order ───────────────────────────────────────
          _SectionHeader(title: tr('priority_order')),
          Text(
            tr('priority_hint'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _prioritySearchController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: 'Rechercher un jeu…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: _priorityQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _prioritySearchController.clear();
                        setState(() => _priorityQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _priorityQuery = v),
          ),
          const SizedBox(height: 8),
          Card(
            child: _priorityOrder.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('—'),
                  )
                : _priorityQuery.isNotEmpty
                    // Filtered view: reordering is disabled while searching
                    // (indices wouldn't map cleanly back to the full list),
                    // but a tap moves the game straight to the top.
                    ? Column(
                        children: [
                          for (final id in _priorityOrder.where((id) =>
                              (_games[id] ?? id)
                                  .toLowerCase()
                                  .contains(_priorityQuery.toLowerCase())))
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                child: Text('${_priorityOrder.indexOf(id) + 1}',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              title: Text(_games[id] ?? id),
                              trailing: IconButton(
                                icon: const Icon(Icons.vertical_align_top, size: 18),
                                tooltip: 'Mettre en premier',
                                onPressed: () {
                                  setState(() {
                                    _priorityOrder.remove(id);
                                    _priorityOrder.insert(0, id);
                                  });
                                  _savePriority();
                                },
                              ),
                            ),
                        ],
                      )
                    : ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _priorityOrder.removeAt(oldIndex);
                        _priorityOrder.insert(newIndex, item);
                      });
                      _savePriority();
                    },
                    children: [
                      for (var i = 0; i < _priorityOrder.length; i++)
                        ListTile(
                          key: ValueKey(_priorityOrder[i]),
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${i + 1}',
                                style: const TextStyle(fontSize: 12)),
                          ),
                          title: Text(_games[_priorityOrder[i]] ?? _priorityOrder[i]),
                          trailing: const Icon(Icons.drag_handle),
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ── Excluded games ────────────────────────────────────────
          _SectionHeader(title: tr('excluded_games')),
          Text(
            tr('excluded_games_hint'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: 'Rechercher un jeu…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Card(
            child: _filteredGames.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Aucun jeu trouvé.'),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final entry in _filteredGames)
                          CheckboxListTile(
                            dense: true,
                            title: Text(entry.value),
                            value: _excluded.contains(entry.key),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _excluded.add(entry.key);
                                } else {
                                  _excluded.remove(entry.key);
                                }
                              });
                              _saveExcluded();
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}