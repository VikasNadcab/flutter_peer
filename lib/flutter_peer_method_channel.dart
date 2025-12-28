import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_peer_platform_interface.dart';

/// An implementation of [FlutterPeerPlatform] that uses method channels.
class MethodChannelFlutterPeer extends FlutterPeerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_peer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
