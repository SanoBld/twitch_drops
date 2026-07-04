import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'twitch_constants.dart';
import 'log_service.dart';

// Listens to Twitch's PubSub service for real-time events: channel
// online/offline status, viewer counts, AND (critically) authoritative
// drop-progress / drop-claim confirmations from Twitch itself via the
// "user-drop-events.<userId>" topic. This is the same mechanism the
// reference TwitchDropsMiner project uses to show real progress instead
// of a locally-guessed estimate.
class TwitchSocketService {
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  final void Function(Map<String, dynamic> event) onEvent;
  final _log = LogService();

  TwitchSocketService(this.onEvent);

  // authToken is required for authenticated topics like user-drop-events.
  void connect(List<String> topics, {String? authToken}) {
    _channel = WebSocketChannel.connect(Uri.parse(TwitchConstants.wsUrl));
    _channel!.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data) as Map<String, dynamic>;
          onEvent(msg);
        } catch (e) {
          _log.log('Failed to decode pubsub message: $e', tag: 'Socket');
        }
      },
      onError: (e) => _log.log('Socket error: $e', tag: 'Socket'),
      onDone: () => _log.log('Socket closed', tag: 'Socket'),
    );

    final listenData = <String, dynamic>{'topics': topics};
    if (authToken != null) listenData['auth_token'] = authToken;

    _channel!.sink.add(jsonEncode({
      'type': 'LISTEN',
      'nonce': DateTime.now().millisecondsSinceEpoch.toString(),
      'data': listenData,
    }));

    // Twitch PubSub requires a PING at least every 5 minutes or it
    // disconnects; send one every 4 minutes to stay alive.
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(minutes: 4), (_) {
      _channel?.sink.add(jsonEncode({'type': 'PING'}));
    });
  }

  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
  }
}