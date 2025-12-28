import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_peer/flutter_peer.dart';
import 'package:flutter_peer/flutter_peer_platform_interface.dart';
import 'package:flutter_peer/flutter_peer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterPeerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterPeerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterPeerPlatform initialPlatform = FlutterPeerPlatform.instance;

  test('$MethodChannelFlutterPeer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterPeer>());
  });

  test('getPlatformVersion', () async {
    FlutterPeer flutterPeerPlugin = FlutterPeer();
    MockFlutterPeerPlatform fakePlatform = MockFlutterPeerPlatform();
    FlutterPeerPlatform.instance = fakePlatform;

    expect(await flutterPeerPlugin.getPlatformVersion(), '42');
  });
}
