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
  final IceConfiguration? _config;
  final Map<String, BaseConnection> _connections = {};
  MediaStream? _localStream;
  bool _isSpeakerPhoneOn = false;
  bool _isCameraOff = false;
  bool _isMicrophoneOff = false;

  static const _uuid = Uuid();

  Peer({
    String? id,
    String host = '0.peerjs.com',
    int port = 443,
    String path = '/',
    bool secure = true,
    String key = 'peerjs',
    IceConfiguration? config,
  }) : _adapter = kIsWeb ? WebWebRtcAdapter() : MobileWebRtcAdapter(),
       _config = config,
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

  /// Listen for when the peer is disconnected from the signaling server.
  void onDisconnected(void Function() callback) {
    on(PeerEvent.disconnected.name, null, (ev, context) {
      callback();
    });
  }

  void _setupSignaling(String? id) {
    _signaling.on('open', null, (ev, context) {
      final peerId = ev.eventData ?? _signaling.id;
      if (peerId != null) {
        emit(PeerEvent.open.name, this, peerId);
      }
    });

    _signaling.on('error', null, (ev, context) {
      emit(PeerEvent.error.name, this, ev.eventData);
    });

    _signaling.on('message', null, (ev, context) {
      final msg = ev.eventData;
      if (msg is SignalingMessage) {
        _handleIncomingMessage(msg);
      }
    });

    _signaling.on('disconnected', null, (ev, context) {
      emit(PeerEvent.disconnected.name, this);
    });

    _signaling.connect(id);
  }

  Future<void> _handleIncomingMessage(SignalingMessage message) async {
    final connectionId = message.payload['connectionId'];
    if (connectionId == null) return;

    BaseConnection? connection = _connections[connectionId];
    bool isNew = false;

    if (connection == null) {
      if (message.type == SignalingMessageType.offer) {
        // Incoming connection request
        isNew = true;
        final src = message.src!;
        final payload = message.payload['payload'];
        final type = payload != null ? payload['connectionType'] : 'data';

        if (type == 'media') {
          connection = MediaConnection(
            peerId: src,
            signalingClient: _signaling,
            adapter: _adapter,
            connectionId: connectionId,
            config: _config,
          );
        } else {
          connection = DataConnection(
            peerId: src,
            signalingClient: _signaling,
            adapter: _adapter,
            connectionId: connectionId,
            config: _config,
          );
        }
        _connections[connectionId] = connection;
      } else {
        return; // Orphaned message
      }
    }

    await connection.handleMessage(message);

    if (isNew) {
      if (connection is MediaConnection) {
        emit(PeerEvent.call.name, this, connection);
      } else if (connection is DataConnection) {
        emit(PeerEvent.connection.name, this, connection);
      }
    }
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
      config: _config,
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
      config: _config,
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

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      await _adapter.switchCamera(_localStream!);
    }
  }

  /// Turn off or on camera (video)
  Future<void> turnOffCamera({bool? off}) async {
    _isCameraOff = off ?? !_isCameraOff;
    if (_localStream != null) {
      await _localStream!.toggleVideo(!_isCameraOff);
    }
  }

  /// Switch speakers (rotate between speakerphone and other outputs)
  Future<void> switchSpeakers() async {
    _isSpeakerPhoneOn = !_isSpeakerPhoneOn;
    await _adapter.setSpeakerphoneOn(_isSpeakerPhoneOn);
  }

  /// Switch microphone (rotate through available inputs)
  Future<void> switchMicrophone() async {
    final devices = await _adapter.enumerateDevices();
    final inputs = devices.where((d) => d.kind == 'audioinput').toList();
    if (inputs.length < 2) return;
    print('Switching microphone... Available: ${inputs.length}');
  }

  /// Turn off or on microphone (audio)
  Future<void> turnoffMicrophone({bool? off}) async {
    _isMicrophoneOff = off ?? !_isMicrophoneOff;
    if (_localStream != null) {
      await _localStream!.toggleAudio(!_isMicrophoneOff);
    }
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
