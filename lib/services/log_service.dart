import 'dart:async';

// Single log entry with timestamp, tag (source) and message.
class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  LogEntry(this.time, this.tag, this.message);

  @override
  String toString() {
    final ts = time.toIso8601String().substring(11, 19);
    return '[$ts] [$tag] $message';
  }
}

// In-memory log buffer, viewable directly in the app (no console needed).
// Singleton via a default (unnamed) constructor, so `LogService()` anywhere
// in the app always returns the same shared instance.
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const int _maxEntries = 500;
  final List<LogEntry> _entries = [];

  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  List<LogEntry> get entries => List.unmodifiable(_entries);

  // debug_screen.dart does: _log.onChanged.listen((_) => setState(...))
  Stream<void> get onChanged => _changeController.stream;

  void log(String message, {String tag = 'App'}) {
    final entry = LogEntry(DateTime.now(), tag, message);
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    // ignore: avoid_print
    print(entry);
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  void clear() {
    _entries.clear();
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  String exportAsText() => _entries.map((e) => e.toString()).join('\n');
}