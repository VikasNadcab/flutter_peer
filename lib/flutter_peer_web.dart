// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_peer_platform_interface.dart';

/// A web implementation of the FlutterPeerPlatform of the FlutterPeer plugin.
class FlutterPeerWeb extends FlutterPeerPlatform {
  /// Constructs a FlutterPeerWeb
  FlutterPeerWeb();

  static void registerWith(Registrar registrar) {
    FlutterPeerPlatform.instance = FlutterPeerWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }
}
