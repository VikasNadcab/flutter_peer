/// WebRTC adapter interface
///
/// This file defines a platform-agnostic contract that every
/// WebRTC implementation (web, mobile, desktop) must follow.
///
/// ❌ No flutter_webrtc imports
/// ❌ No dart:html imports
/// ✅ Pure Dart
///
/// Inspired by PeerJS architecture.

library webrtc_adapter;

/// Represents a generic WebRTC peer connection
abstract class PeerConnection {
  /// Create an SDP offer
  Future<SessionDescription> createOffer();

  /// Create an SDP answer
  Future<SessionDescription> createAnswer();

  /// Set local SDP
  Future<void> setLocalDescription(SessionDescription description);

  /// Set remote SDP
  Future<void> setRemoteDescription(SessionDescription description);

  /// Add local media stream
  Future<void> addStream(MediaStream stream);

  /// Add ICE candidate
  Future<void> addIceCandidate(IceCandidate candidate);

  /// Close connection
  Future<void> close();

  /// Get current signaling state
  Future<SignalingState> getSignalingState();

  /// Connection state stream
  Stream<PeerConnectionState> get onConnectionState;

  /// ICE candidate stream
  Stream<IceCandidate> get onIceCandidate;

  /// Data channel stream (incoming)
  Stream<DataChannel> get onDataChannel;

  /// Remote media stream stream
  Stream<MediaStream> get onTrack;
}

/// Media stream
abstract class MediaStream {
  String get id;

  /// Underlying native stream (e.g. RTCVideoRenderer.srcObject)
  dynamic get srcObject;

  List<MediaTrack> getTracks();

  Future<void> dispose();

  /// Toggle audio track
  Future<void> toggleAudio(bool enabled);

  /// Toggle video track
  Future<void> toggleVideo(bool enabled);
}

/// Media device info
class MediaDeviceInfo {
  final String deviceId;
  final String label;
  final String kind;
  final String groupId;

  const MediaDeviceInfo({
    required this.deviceId,
    required this.label,
    required this.kind,
    required this.groupId,
  });
}

/// Media constraints
class MediaConstraints {
  final bool audio;
  final bool video;
  final String? audioInputId;
  final String? videoInputId;

  const MediaConstraints({
    this.audio = true,
    this.video = true,
    this.audioInputId,
    this.videoInputId,
  });
}

/// WebRTC adapter contract
abstract class WebRtcAdapter {
  /// Create a peer connection
  Future<PeerConnection> createPeerConnection({
    required IceConfiguration iceConfiguration,
  });

  /// Create a data channel
  Future<DataChannel> createDataChannel({
    required PeerConnection peerConnection,
    required String label,
    DataChannelInit? options,
  });

  /// Get user media (camera/microphone)
  Future<MediaStream> getUserMedia(MediaConstraints constraints);

  /// Get display media (screen sharing)
  Future<MediaStream> getDisplayMedia(MediaConstraints constraints);

  /// Switch camera
  Future<void> switchCamera(MediaStream stream);

  /// Get available media devices
  Future<List<MediaDeviceInfo>> enumerateDevices();

  /// Set speakerphone on/off (Mobile specific)
  Future<void> setSpeakerphoneOn(bool enable);

  /// Set audio output device (Web/Desktop specific)
  Future<void> setAudioOutput(String deviceId);

  /// Dispose adapter
  Future<void> dispose();
}

/// ICE configuration
class IceConfiguration {
  final List<IceServer> iceServers;

  const IceConfiguration({required this.iceServers});
}

/// ICE server
class IceServer {
  final List<String> urls;
  final String? username;
  final String? credential;

  const IceServer({required this.urls, this.username, this.credential});
}

/// SDP description
class SessionDescription {
  final String sdp;
  final SdpType type;

  const SessionDescription({required this.sdp, required this.type});
}

/// SDP type
enum SdpType { offer, answer }

/// ICE candidate
class IceCandidate {
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  const IceCandidate({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });
}

/// Peer connection state
enum PeerConnectionState {
  idle,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

/// Signaling state
enum SignalingState {
  stable,
  haveLocalOffer,
  haveRemoteOffer,
  haveLocalPranswer,
  haveRemotePranswer,
  closed,
}

/// Media track
abstract class MediaTrack {
  String get id;
  String get kind; // audio | video
  bool get enabled;

  Future<void> setEnabled(bool enabled);

  Future<void> stop();
}

/// Data channel
abstract class DataChannel {
  String get label;

  /// Data stream
  Stream<dynamic> get onMessage;

  /// State stream
  Stream<DataChannelState> get onState;

  /// Send data
  Future<void> send(dynamic data);

  /// Close channel
  Future<void> close();
}

/// Data channel init options
class DataChannelInit {
  final bool ordered;
  final int? maxPacketLifeTime;
  final int? maxRetransmits;

  const DataChannelInit({
    this.ordered = true,
    this.maxPacketLifeTime,
    this.maxRetransmits,
  });
}

/// Data channel state
enum DataChannelState { connecting, open, closing, closed }

/// Video view object fit
enum PeerVideoViewObjectFit { contain, cover }
