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

    peer.on('open', null, (ev, context) {
      final getId = ev.eventData;
      print("found ${ev.toString()} $getId");
      setState(() {
        myId = id;
      });
    });

    peer.on('connection', null, (ev, context) {
      final conn = ev.eventData;
      print("found ${ev.sender} $conn");
      if (conn is DataConnection) {
        _setupConnection(conn);
      }
    });

    peer.on('error', null, (ev, context) {
      debugPrint('Peer error: ${ev.eventData}');
    });
  }

  void _setupConnection(DataConnection conn) {
    setState(() {
      activeConn = conn;
    });

    conn.on('open', null, (ev, context) {
      print("connected ${ev} ");
      setState(() {
        messages.add('Connected to ${conn.peerId}');
      });
    });

    conn.on('data', null, (ev, context) {
      setState(() {
        messages.add('${conn.peerId}: ${ev.eventData}');
      });
    });

    conn.on('close', null, (ev, context) {
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
