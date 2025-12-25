import 'dart:async';
import 'package:eventify/eventify.dart';
import '../webrtc/webrtc_adapter.dart';
import '../signaling/signaling_client.dart';
import '../signaling/signaling_protocol.dart';

enum ConnectionEvent { open, close, error, data, stream }

abstract class BaseConnection extends EventEmitter {
  final String peerId;
  final SignalingClient signalingClient;
  final WebRtcAdapter adapter;
  final String connectionId;

  PeerConnection? pc;
  bool isOpen = false;
  bool isOfferer = false;
  bool hasRemoteDescription = false;

  BaseConnection({
    required this.peerId,
    required this.signalingClient,
    required this.adapter,
    required this.connectionId,
  });

  bool get isConnected => isOpen;

  /// Listen for when the connection is open.
  void onOpen(void Function() callback) {
    on(ConnectionEvent.open.name, null, (ev, context) {
      callback();
    });
  }

  /// Listen for when the connection is closed.
  void onClose(void Function() callback) {
    on(ConnectionEvent.close.name, null, (ev, context) {
      callback();
    });
  }

  /// Listen for errors.
  void onError(void Function(dynamic error) callback) {
    on(ConnectionEvent.error.name, null, (ev, context) {
      callback(ev.eventData);
    });
  }

  Future<void> initialize();
  void handleMessage(SignalingMessage message);
  void close();

  void sendSignal(SignalingMessageType type, dynamic payload) {
    signalingClient.send(
      SignalingMessage(
        type: type,
        src: signalingClient.id,
        dst: peerId,
        payload: {'connectionId': connectionId, 'payload': payload},
      ),
    );
  }
}
