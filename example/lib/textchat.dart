import 'package:flutter/material.dart';
import 'package:flutter_peer/flutter_peer.dart';
import 'package:uuid/uuid.dart';

class TextChat extends StatefulWidget {
  const TextChat({super.key});

  @override
  State<TextChat> createState() => _TextChatState();
}

class _TextChatState extends State<TextChat> {
  late Peer peer;
  String? myId;
  String destId = '';
  final TextEditingController _msgController = TextEditingController();
  final List<String> messages = [];
  DataConnection? activeConn;

  @override
  void initState() {
    super.initState();
    _initPeer();
  }

  void _initPeer() {
    final id = Uuid().v4();
    peer = Peer(id: id);

    peer.onOpen((id) {
      print("found peer with id: $id");
      setState(() {
        myId = id;
      });
    });

    peer.onConnection((conn) {
      print("received connection from ${conn.peerId}");
      _setupConnection(conn);
    });

    peer.onError((err) {
      debugPrint('Peer error: $err');
    });
  }

  void _setupConnection(DataConnection conn) {
    setState(() {
      activeConn = conn;
    });

    conn.onOpen(() {
      print("connection opened");
      setState(() {
        messages.add('Connected to ${conn.peerId}');
      });
    });

    conn.onData((data) {
      setState(() {
        messages.add('${conn.peerId}: $data');
      });
    });

    conn.onClose(() {
      setState(() {
        messages.add('Disconnected');
        activeConn = null;
      });
    });
  }

  void _connect() {
    if (destId.isNotEmpty) {
      try {
        final conn = peer.connect(destId);
        print("conn ${conn.peerId}");
        _setupConnection(conn);
      } catch (e) {
        print("error $e");
      }
    }
  }

  void _send() {
    if (activeConn != null && _msgController.text.isNotEmpty) {
      activeConn!.send(_msgController.text);
      setState(() {
        messages.add('Me: ${_msgController.text}');
        _msgController.clear();
      });
    }
  }

  @override
  void dispose() {
    peer.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Peer Example')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SelectableText(
                'My ID: ${myId ?? "Connecting..."}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Destination Peer ID',
                      ),
                      onChanged: (v) => destId = v,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _connect,
                    child: const Text('Connect'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, i) => Text(messages[i]),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                      ),
                    ),
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
