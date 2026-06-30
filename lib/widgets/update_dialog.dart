import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

Future<void> showUpdateDialogIfNeeded(BuildContext context) async {
  try {
    final info = await UpdateService().checkForUpdate();
    if (info == null || !context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update available: ${info.version}'),
        content: Text(info.notes.isEmpty ? 'A new version is available.' : info.notes),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              launchUrl(Uri.parse(info.url));
              Navigator.pop(ctx);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  } catch (_) {
    // Silent fail: no internet or rate-limited, not critical.
  }
}
