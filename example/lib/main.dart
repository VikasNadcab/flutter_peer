import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_peer/flutter_peer.dart';
import 'package:flutter_peer_example/textchat.dart';
import 'package:flutter_peer_example/videoChat.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Simple Connect Example")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton.extended(
              heroTag: "TextChat",
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => TextChat()));
              },
              label: Text("Text Chat"),
            ),
            FloatingActionButton.extended(
              heroTag: "VideoChat",
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => Videochat()));
              },
              label: Text("Video Chat"),
            ),
          ],
        ),
      ),
    );
  }
}
