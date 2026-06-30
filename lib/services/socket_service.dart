import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'twitch_constants.dart';

// Listens to channel status updates (online/offline, viewer count).
class TwitchSocketService {
  WebSocketChannel? _channel;
  final void Function(Map<String, dynamic> event) onEvent;

  TwitchSocketService(this.onEvent);

  void connect(List<String> topics) {
    _channel = WebSocketChannel.connect(Uri.parse(TwitchConstants.wsUrl));
    _channel!.stream.listen((data) {
      final msg = jsonDecode(data);
      onEvent(msg);
    });
    _channel!.sink.add(jsonEncode({
      'type': 'LISTEN',
      'data': {'topics': topics}
    }));
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
