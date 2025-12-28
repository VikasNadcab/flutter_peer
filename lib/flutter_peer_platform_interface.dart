import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_peer_method_channel.dart';

abstract class FlutterPeerPlatform extends PlatformInterface {
  /// Constructs a FlutterPeerPlatform.
  FlutterPeerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterPeerPlatform _instance = MethodChannelFlutterPeer();

  /// The default instance of [FlutterPeerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterPeer].
  static FlutterPeerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterPeerPlatform] when
  /// they register themselves.
  static set instance(FlutterPeerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
