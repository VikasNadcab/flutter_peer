import 'dart:async';
import 'base_connection.dart';
import '../webrtc/webrtc_adapter.dart';
import '../signaling/signaling_protocol.dart';

class RemoteStreamChange {
  final bool audio;
  final bool video;
  RemoteStreamChange({required this.audio, required this.video});
}

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
    super.config,
  });

  bool _isSpeakerPhoneOn = false;
  bool _isCameraOff = false;
  bool _isMicrophoneOff = false;

  bool _remoteAudioEnabled = true;
  bool _remoteVideoEnabled = true;

  bool get isCameraOff => _isCameraOff;
  bool get isMicrophoneOff => _isMicrophoneOff;
  bool get remoteAudioEnabled => _remoteAudioEnabled;
  bool get remoteVideoEnabled => _remoteVideoEnabled;

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (localStream != null) {
      await adapter.switchCamera(localStream!);
    }
  }

  /// Turn off or on camera (video)
  Future<void> turnOffCamera({bool? off}) async {
    _isCameraOff = off ?? !_isCameraOff;
    if (localStream != null) {
      await localStream!.toggleVideo(!_isCameraOff);
      _sendMediaState();
    }
  }

  /// Switch speakers (rotate between speakerphone and other outputs)
  Future<void> switchSpeakers() async {
    // For mobile, we commonly toggle between speaker and earpiece/headset
    _isSpeakerPhoneOn = !_isSpeakerPhoneOn;
    await adapter.setSpeakerphoneOn(_isSpeakerPhoneOn);

    // TODO: For Web/Desktop, iterate through audiooutput devices
  }

  /// Switch microphone (rotate through available inputs)
  Future<void> switchMicrophone() async {
    final devices = await adapter.enumerateDevices();
    final inputs = devices.where((d) => d.kind == 'audioinput').toList();
    if (inputs.length < 2) return;

    // Find current input and switch to next
    // This requires re-initializing the local stream with the new deviceId
    // and replacing the track in the peer connection.
    // For now we just print for debugging as the adapter doesn't support track replacement yet.
    // print('Switching microphone... Available: ${inputs.length}');
  }

  /// Turn off or on microphone (audio)
  Future<void> turnoffMicrophone({bool? off}) async {
    _isMicrophoneOff = off ?? !_isMicrophoneOff;
    if (localStream != null) {
      await localStream!.toggleAudio(!_isMicrophoneOff);
      _sendMediaState();
    }
  }

  void _sendMediaState() {
    sendSignal(SignalingMessageType.mediaState, {
      'audio': !_isMicrophoneOff,
      'video': !_isCameraOff,
    });
  }

  /// Listen for incoming media streams.
  void onStream(void Function(MediaStream stream) callback) {
    on(ConnectionEvent.stream.name, null, (ev, context) {
      callback(ev.eventData as MediaStream);
    });
  }

  /// Listen for remote media state changes (camera/mic toggle).
  void onRemoteStreamChange(void Function(RemoteStreamChange change) callback) {
    on(ConnectionEvent.mediaState.name, null, (ev, context) {
      callback(ev.eventData as RemoteStreamChange);
    });
  }

  @override
  Future<void> initialize() async {
    pc = await adapter.createPeerConnection(
      iceConfiguration:
          config ??
          const IceConfiguration(
            iceServers: [
              IceServer(urls: ['stun:stun4.l.google.com:19302']),
            ],
          ),
    );

    pc!.onIceCandidate.listen((candidate) {
      // print('Sending ICE candidate to ${peerId}');
      sendSignal(SignalingMessageType.candidate, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    });

    pc!.onTrack.listen((stream) {
      // print(
      //   'Received remote stream from $peerId, tracks: ${stream.getTracks().length}',
      // );

      // If we already have this stream, don't replace it, just notify
      if (remoteStream?.id == stream.id) {
        emit(ConnectionEvent.stream.name, this, stream);
        return;
      }

      remoteStream = stream;
      isOpen = true;
      emit(ConnectionEvent.stream.name, this, stream);
    });

    // Add local stream if present
    if (localStream != null) {
      // print('Adding local stream to peer connection');
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
  Future<void> handleMessage(SignalingMessage message) async {
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
      case SignalingMessageType.mediaState:
        _remoteAudioEnabled = payload['audio'] ?? true;
        _remoteVideoEnabled = payload['video'] ?? true;
        emit(
          ConnectionEvent.mediaState.name,
          this,
          RemoteStreamChange(
            audio: _remoteAudioEnabled,
            video: _remoteVideoEnabled,
          ),
        );
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
