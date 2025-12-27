# Flutter Peer

A developer-friendly, lightweight, and reliable WebRTC plugin for Flutter, inspired by [PeerJS](https://peerjs.com/). Establish direct peer-to-peer data, video, and audio connections with ease.

[![pub package](https://img.shields.io/pub/v/flutter_peer.svg)](https://pub.dev/packages/flutter_peer)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## 🚀 Features

- **Cross-Platform**: Works out-of-the-box on Android, iOS, Web, and Desktop.
- **PeerJS Protocol**: Fully compatible with existing `peerjs-server` instances.
- **Type-Safe Events**: Uses Enums and dedicated callback methods (`onOpen`, `onData`, etc.) for a better developer experience.
- **Simplicity**: No complex WebRTC negotiation (SDP/ICE) to manage; just use IDs to connect.
- **Built-in Media Controls**: Easy methods to switch cameras, toggle audio/video, and manage speakerphone.
- **Standard-compliant**: Uses standard WebRTC under the hood via `flutter_webrtc`.

## 📦 Installation

Add `flutter_peer` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_peer: ^0.0.1
```

## 🛠️ Platform Setup

### Android
Add permissions to your `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

### iOS
Add keys to your `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) needs camera access for video calls.</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) needs microphone access for audio calls.</string>
```

## 📖 Quick Start

### 1. Initialize Peer
By default, it connects to the public PeerJS cloud server.

```dart
import 'package:flutter_peer/flutter_peer.dart';

// Create a peer with a random ID
final peer = Peer();

peer.onOpen((id) {
  print('My peer ID is: $id');
});
```

### 2. Connect and Send Data
Establish a `DataConnection` to another peer.

```dart
final conn = peer.connect('another-peer-id');

conn.onOpen(() {
  conn.send('Hello from Flutter!');
});

conn.onData((data) {
  print('Received data: $data');
});
```

### 3. Make and Receive Calls
Establish a `MediaConnection` for audio/video.

```dart
// To make a call
final stream = await peer.getLocalStream();
final call = peer.call('another-peer-id', stream);

call.onStream((remoteStream) {
  // Use remoteStream in a RTCVideoRenderer
});

// To receive a call
peer.onCall((call) async {
  final localStream = await peer.getLocalStream();
  call.answer(localStream);
  
  call.onStream((remoteStream) {
    // Show remote video
  });
});
```

## ⚙️ Advanced Configuration

### Custom Signaling Server
Host your own [PeerServer](https://github.com/peers/peerjs-server) for production apps.

```dart
final peer = Peer(
  id: 'my-custom-id',
  host: 'your-peer-server.com',
  port: 443,
  secure: true,
  path: '/myapp',
  key: 'peerjs',
);
```

### Custom ICE (STUN/TURN) Servers
Configure custom ICE servers for better NAT traversal.

```dart
final peer = Peer(
  config: IceConfiguration(
    iceServers: [
      IceServer(urls: ['stun:stun.l.google.com:19302']),
      IceServer(
        urls: ['turn:your-turn-server.com'],
        username: 'user',
        credential: 'password',
      ),
    ],
  ),
);
```

### Media Controls
`flutter_peer` provides high-level methods to control media streams:

```dart
await peer.switchCamera(); // Switch between front/back
await peer.turnOffCamera(off: true); // Toggle video
await peer.turnoffMicrophone(off: true); // Toggle audio
await peer.switchSpeakers(); // Toggle speakerphone
```

## 📱 Platform Support

| Platform | Support |
| :--- | :--- |
| **Android** | ✅ |
| **iOS** | ✅ |
| **Web** | ✅ |
| **MacOS** | ✅ |
| **Windows** | ✅ |
| **Linux** | ✅ |

## 📄 License

This project is licensed under the Apache 2.0 License.

