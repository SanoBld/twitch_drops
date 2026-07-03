import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final _log = LogService();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _log.onChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _log.exportAsText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _log.entries;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug logs'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: entries.isEmpty ? null : _copyAll,
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: entries.isEmpty
                ? null
                : () => setState(() => _log.clear()),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                'No logs yet. Refresh campaigns to generate some.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final e = entries[i];
                  final isError = e.message.toLowerCase().contains('error') ||
                      e.message.toLowerCase().contains('null') ||
                      e.tag.toLowerCase().contains('error');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText(
                      e.toString(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: isError ? cs.error : cs.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: entries.isEmpty
          ? null
          : FloatingActionButton.small(
              onPressed: () {
                _scrollController.jumpTo(
                  _scrollController.position.maxScrollExtent,
                );
              },
              child: const Icon(Icons.arrow_downward),
            ),
    );
  }
}
