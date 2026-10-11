import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'auth_service.dart';

/// Event received from the backend WebSocket.
class RiderWsEvent {
  const RiderWsEvent({required this.type, this.payload});

  final String type;
  final dynamic payload;

  factory RiderWsEvent.fromJson(Map<String, dynamic> json) {
    return RiderWsEvent(
      type: json['type'] as String? ?? '',
      payload: json['payload'],
    );
  }
}

/// Manages a persistent WebSocket connection for the rider app.
///
/// Receives:
/// - `delivery.available` — new delivery requests to accept
/// - `delivery.status_changed` — delivery lifecycle transitions
/// - `delivery.location_updated` — location confirmation
/// - `notification.new` — in-app notifications
/// - `chat.message` — new messages on a delivery thread
class RiderWebSocket {
  RiderWebSocket({required this.api});

  final ApiClient api;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  String? _token;

  final _events = StreamController<RiderWsEvent>.broadcast();
  Stream<RiderWsEvent> get events => _events.stream;

  Stream<RiderWsEvent> get newDelivery =>
      events.where((e) => e.type == 'delivery.available');
  Stream<RiderWsEvent> get deliveryStatus =>
      events.where((e) => e.type == 'delivery.status_changed');
  Stream<RiderWsEvent> get notification =>
      events.where((e) => e.type == 'notification.new');
  Stream<RiderWsEvent> get requestAvailable =>
      events.where((e) => e.type == 'request.available');
  Stream<RiderWsEvent> get requestFulfilled =>
      events.where((e) => e.type == 'request.fulfilled');
  Stream<RiderWsEvent> get requestExpired =>
      events.where((e) => e.type == 'request.expired');

  /// New messages on a customer chat thread (`chat.message`).
  Stream<RiderWsEvent> get chatMessage =>
      events.where((e) => e.type == 'chat.message');

  void connect(String token) {
    disconnect();
    _intentionalClose = false;
    _token = token;
    _doConnect();
  }

  void _doConnect() {
    if (_intentionalClose) return;

    // Re-read the live access token on every (re)connect so a refreshed
    // session keeps the socket authenticated.
    if (!AuthSession.instance.isAuthenticated) {
      _intentionalClose = true;
      return;
    }
    final freshToken = AuthSession.instance.accessToken;
    if (freshToken == null || freshToken.isEmpty) return;
    _token = freshToken;

    final wsUrl = api.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsUrl/ws?token=$_token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _events.add(RiderWsEvent.fromJson(json));
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          if (!_intentionalClose) _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _doConnect);
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}
