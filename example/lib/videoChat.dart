import 'package:flutter/material.dart';
import 'package:flutter_peer/flutter_peer.dart';
import 'package:uuid/uuid.dart';

class Videochat extends StatefulWidget {
  const Videochat({super.key});

  @override
  State<Videochat> createState() => _VideochatState();
}

class _VideochatState extends State<Videochat> {
  late Peer peer;
  String? myId;
  String destId = '';
  MediaConnection? activeCall;

  @override
  void initState() {
    super.initState();
    _initPeer();
  }

  void _initPeer() {
    final id = Uuid().v4();
    peer = Peer(id: id);

    peer.onOpen((id) {
      if (mounted) setState(() => myId = id);
    });

    peer.onCall((call) {
      _handleIncomingCall(call);
    });
  }

  void _setupCall(MediaConnection call) {
    setState(() => activeCall = call);

    call.onStream((stream) => setState(() {}));
    call.onClose(() => setState(() => activeCall = null));
  }

  Future<void> _handleIncomingCall(MediaConnection call) async {
    final stream = await peer.getLocalStream();
    await call.answer(stream);
    _setupCall(call);
  }

  void _makeCall() async {
    if (destId.isEmpty) return;
    final stream = await peer.getLocalStream();
    final call = peer.call(destId, stream);
    _setupCall(call);
  }

  @override
  void dispose() {
    peer.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simplified Video Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'My ID: ${myId ?? "..."}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'Remote ID'),
                  onChanged: (v) => destId = v,
                ),
                ElevatedButton(onPressed: _makeCall, child: const Text('Call')),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Remote Video
                PeerVideoView(
                  stream: activeCall?.remoteStream,
                  objectFit: PeerVideoViewObjectFit.cover,
                ),
                // Local Video
                Positioned(
                  right: 20,
                  bottom: 20,
                  width: 120,
                  height: 160,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                    ),
                    child: PeerVideoView(
                      stream: peer.localStream,
                      mirror: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (activeCall != null)
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red, size: 40),
              onPressed: () => activeCall?.close(),
            ),
        ],
      ),
    );
  }
}
