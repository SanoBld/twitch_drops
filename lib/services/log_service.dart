import 'dart:async';

/// Simple in-memory log buffer so logs can be inspected from inside the
/// running app (useful on release builds / when the user has no console).
class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  LogEntry(this.tag, this.message) : time = DateTime.now();

  @override
  String toString() {
    final t = time.toIso8601String().substring(11, 19); // HH:MM:SS
    return '[$t] [$tag] $message';
  }
}

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const int _maxEntries = 500;

  final List<LogEntry> _entries = [];
  final _controller = StreamController<List<LogEntry>>.broadcast();

  List<LogEntry> get entries => List.unmodifiable(_entries);
  Stream<List<LogEntry>> get onChanged => _controller.stream;

  void log(String message, {String tag = 'App'}) {
    _entries.add(LogEntry(tag, message));
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    _controller.add(entries);
  }

  void clear() {
    _entries.clear();
    _controller.add(entries);
  }

  String exportAsText() => _entries.map((e) => e.toString()).join('\n');
}
