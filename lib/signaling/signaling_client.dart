import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:eventify/eventify.dart';
import 'signaling_protocol.dart';

class SignalingClient extends EventEmitter {
  final String host;
  final int port;
  final String path;
  final bool secure;
  final String key;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _id;
  bool _connected = false;

  SignalingClient({
    required this.host,
    required this.port,
    this.path = '/',
    this.secure = true,
    this.key = 'peerjs',
  });

  String? get id => _id;
  bool get isConnected => _connected;

  Future<void> connect([String? id]) async {
    _id = id;
    final protocol = secure ? 'wss' : 'ws';
    final randomToken = _generateToken();

    final portPart = (secure && port == 443) || (!secure && port == 80)
        ? ''
        : ':$port';
    final normalizedPath = path.endsWith('/') ? path : '$path/';

    final url = Uri.parse(
      '$protocol://$host$portPart${normalizedPath}peerjs?key=$key&id=${id ?? ""}&token=$randomToken',
    );

    print('Signaling connecting to: $url');
    try {
      _channel = WebSocketChannel.connect(url);
      _connected = true;
    } catch (e) {
      _connected = false;
      emit('error', this, 'Could not connect to signaling server: $e');
      return;
    }

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final Map<String, dynamic> json = jsonDecode(data);
          final message = SignalingMessage.fromJson(json);
          _handleMessage(message);
        } catch (e) {
          print('Error parsing signaling message: $e');
        }
      },
      onDone: () => _handleDisconnect(),
      onError: (err) => _handleError(err),
    );
  }

  void send(SignalingMessage message) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(message.toJson()));
    }
  }

  void _handleMessage(SignalingMessage message) {
    switch (message.type) {
      case SignalingMessageType.open:
        if (message.payload != null) {
          _id = message.payload;
        }
        emit('open', this, _id);
        break;
      case SignalingMessageType.error:
        emit('error', this, message.payload);
        break;
      case SignalingMessageType.idTaken:
        emit('error', this, 'ID is already taken');
        break;
      case SignalingMessageType.invalidId:
        emit('error', this, 'Invalid ID');
        break;
      case SignalingMessageType.offer:
      case SignalingMessageType.answer:
      case SignalingMessageType.candidate:
      case SignalingMessageType.leave:
      case SignalingMessageType.expire:
      case SignalingMessageType.mediaState:
        emit('message', this, message);
        break;
    }
  }

  void _handleDisconnect() {
    _connected = false;
    emit('disconnected', this);
  }

  void _handleError(dynamic err) {
    emit('error', this, err);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _connected = false;
  }

  String _generateToken() {
    return (DateTime.now().millisecondsSinceEpoch % 1000000).toString();
  }
}
