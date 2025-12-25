import 'dart:async';
import 'base_connection.dart';
import '../webrtc/webrtc_adapter.dart';
import '../signaling/signaling_protocol.dart';

class MediaConnection extends BaseConnection {
  final MediaStream? localStream;
  MediaStream? remoteStream;
  final List<dynamic> _pendingCandidates = [];

  MediaConnection({
    required super.peerId,
    required super.signalingClient,
    required super.adapter,
    required super.connectionId,
    this.localStream,
  });

  /// Listen for incoming media streams.
  void onStream(void Function(MediaStream stream) callback) {
    on(ConnectionEvent.stream.name, null, (ev, context) {
      callback(ev.eventData as MediaStream);
    });
  }

  @override
  Future<void> initialize() async {
    pc = await adapter.createPeerConnection(
      iceConfiguration: const IceConfiguration(
        iceServers: [
          IceServer(urls: ['stun:stun.l.google.com:19302']),
        ],
      ),
    );

    pc!.onIceCandidate.listen((candidate) {
      print('Sending ICE candidate to ${peerId}');
      sendSignal(SignalingMessageType.candidate, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    });

    pc!.onTrack.listen((stream) {
      print('Received remote stream from ${peerId}');
      remoteStream = stream;
      isOpen = true;
      emit('stream', this, stream);
    });

    // Add local stream if present
    if (localStream != null) {
      await pc!.addStream(localStream!);
    }
  }

  Future<void> answer(MediaStream stream) async {
    if (pc == null) await initialize();
    await pc!.addStream(stream);

    final answer = await pc!.createAnswer();
    await pc!.setLocalDescription(answer);

    sendSignal(SignalingMessageType.answer, {
      'sdp': answer.sdp,
      'type': answer.type.name,
    });
  }

  Future<void> call() async {
    isOfferer = true;
    if (pc == null) await initialize();

    final offer = await pc!.createOffer();
    await pc!.setLocalDescription(offer);

    sendSignal(SignalingMessageType.offer, {
      'sdp': offer.sdp,
      'type': offer.type.name,
      'connectionType': 'media',
    });
  }

  @override
  void handleMessage(SignalingMessage message) async {
    final payload = message.payload['payload'];

    switch (message.type) {
      case SignalingMessageType.offer:
        if (isOfferer ||
            (pc != null &&
                (await pc!.getSignalingState()) != SignalingState.stable)) {
          return;
        }
        if (pc == null) await initialize();
        await pc!.setRemoteDescription(
          SessionDescription(sdp: payload['sdp'], type: SdpType.offer),
        );
        hasRemoteDescription = true;

        // Process pending candidates
        for (var cand in _pendingCandidates) {
          await pc!.addIceCandidate(
            IceCandidate(
              candidate: cand['candidate'],
              sdpMid: cand['sdpMid'],
              sdpMLineIndex: cand['sdpMLineIndex'],
            ),
          );
        }
        _pendingCandidates.clear();

        emit('call', this);
        break;
      case SignalingMessageType.answer:
        await pc!.setRemoteDescription(
          SessionDescription(sdp: payload['sdp'], type: SdpType.answer),
        );
        hasRemoteDescription = true;

        // Process pending candidates
        for (var cand in _pendingCandidates) {
          await pc!.addIceCandidate(
            IceCandidate(
              candidate: cand['candidate'],
              sdpMid: cand['sdpMid'],
              sdpMLineIndex: cand['sdpMLineIndex'],
            ),
          );
        }
        _pendingCandidates.clear();
        break;
      case SignalingMessageType.candidate:
        if (!hasRemoteDescription || pc == null) {
          _pendingCandidates.add(payload);
        } else {
          await pc!.addIceCandidate(
            IceCandidate(
              candidate: payload['candidate'],
              sdpMid: payload['sdpMid'],
              sdpMLineIndex: payload['sdpMLineIndex'],
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  @override
  void close() {
    pc?.close();
    remoteStream?.dispose();
    isOpen = false;
    emit('close');
  }
}
