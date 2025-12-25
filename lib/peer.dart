import 'package:eventify/eventify.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import 'signaling/signaling_client.dart';
import 'signaling/signaling_protocol.dart';
import 'webrtc/webrtc_adapter.dart';
import 'webrtc/webrtc_mobile.dart';
import 'webrtc/webrtc_web.dart';
import 'connection/data_connection.dart';
import 'connection/media_connection.dart';
import 'connection/base_connection.dart';

enum PeerEvent { open, connection, call, close, disconnected, error }

class Peer extends EventEmitter {
  final SignalingClient _signaling;
  final WebRtcAdapter _adapter;
  final Map<String, BaseConnection> _connections = {};
  MediaStream? _localStream;

  static const _uuid = Uuid();

  Peer({
    String? id,
    String host = '0.peerjs.com',
    int port = 443,
    String path = '/',
    bool secure = true,
    String key = 'peerjs',
  }) : _adapter = kIsWeb ? WebWebRtcAdapter() : MobileWebRtcAdapter(),
       _signaling = SignalingClient(
         host: host,
         port: port,
         path: path,
         secure: secure,
         key: key,
       ) {
    _setupSignaling(id);
  }

  String? get id => _signaling.id;

  /// Listen for when the peer is open and connected to the signaling server.
  void onOpen(void Function(String id) callback) {
    on(PeerEvent.open.name, null, (ev, context) {
      callback(ev.eventData as String);
    });
  }

  /// Listen for incoming data connections.
  void onConnection(void Function(DataConnection conn) callback) {
    on(PeerEvent.connection.name, null, (ev, context) {
      callback(ev.eventData as DataConnection);
    });
  }

  /// Listen for incoming media calls.
  void onCall(void Function(MediaConnection call) callback) {
    on(PeerEvent.call.name, null, (ev, context) {
      callback(ev.eventData as MediaConnection);
    });
  }

  /// Listen for errors.
  void onError(void Function(dynamic error) callback) {
    on(PeerEvent.error.name, null, (ev, context) {
      callback(ev.eventData);
    });
  }

  /// Listen for when the peer is closed.
  void onClose(void Function() callback) {
    on(PeerEvent.close.name, null, (ev, context) {
      callback();
    });
  }

  void _setupSignaling(String? id) {
    _signaling.on('open', null, (ev, context) {
      emit('open', this, ev.eventData);
    });

    _signaling.on('error', null, (ev, context) {
      emit('error', this, ev.eventData);
    });

    _signaling.on('message', null, (ev, context) {
      final msg = ev.eventData;
      if (msg is SignalingMessage) {
        _handleIncomingMessage(msg);
      }
    });

    _signaling.connect(id);
  }

  void _handleIncomingMessage(SignalingMessage message) {
    final connectionId = message.payload['connectionId'];
    if (connectionId == null) return;

    var connection = _connections[connectionId];

    if (connection == null) {
      if (message.type == SignalingMessageType.offer) {
        // Incoming connection request
        final src = message.src!;
        final payload = message.payload['payload'];
        final type = payload != null ? payload['connectionType'] : 'data';

        if (type == 'media') {
          connection = MediaConnection(
            peerId: src,
            signalingClient: _signaling,
            adapter: _adapter,
            connectionId: connectionId,
          );
          _connections[connectionId] = connection;
          emit('call', this, connection);
        } else {
          connection = DataConnection(
            peerId: src,
            signalingClient: _signaling,
            adapter: _adapter,
            connectionId: connectionId,
          );
          _connections[connectionId] = connection;
          emit('connection', this, connection);
        }
      } else {
        return; // Orphaned message
      }
    }

    connection.handleMessage(message);
  }

  DataConnection connect(
    String peerId, {
    String? label,
    DataChannelInit? options,
  }) {
    if (peerId == id) {
      throw Exception('Cannot connect to self.');
    }
    final connectionId = _uuid.v4();
    final connection = DataConnection(
      peerId: peerId,
      signalingClient: _signaling,
      adapter: _adapter,
      connectionId: connectionId,
      label: label ?? 'peerjs',
      options: options,
    );

    _connections[connectionId] = connection;
    connection.connect(); // Start negotiation

    return connection;
  }

  MediaConnection call(String peerId, MediaStream stream) {
    if (peerId == id) {
      throw Exception('Cannot connect to self.');
    }
    final connectionId = _uuid.v4();
    final connection = MediaConnection(
      peerId: peerId,
      signalingClient: _signaling,
      adapter: _adapter,
      connectionId: connectionId,
      localStream: stream,
    );

    _connections[connectionId] = connection;
    connection.call();

    return connection;
  }

  MediaStream? get localStream => _localStream;

  Future<MediaStream> getLocalStream({
    bool audio = true,
    bool video = true,
  }) async {
    if (_localStream != null) return _localStream!;
    _localStream = await _adapter.getUserMedia(
      MediaConstraints(audio: audio, video: video),
    );
    return _localStream!;
  }

  Future<MediaStream> getUserMedia(MediaConstraints constraints) {
    return _adapter.getUserMedia(constraints);
  }

  Future<MediaStream> getDisplayMedia(MediaConstraints constraints) {
    return _adapter.getDisplayMedia(constraints);
  }

  void disconnect() {
    _signaling.disconnect();
    for (var conn in _connections.values) {
      conn.close();
    }
    _connections.clear();
    _localStream?.dispose();
    _localStream = null;
  }

  void destroy() {
    disconnect();
    _adapter.dispose();
  }
}
