import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import '../webrtc/webrtc_adapter.dart';

/// A simple widget to render a [MediaStream] from the flutter_peer plugin.
class PeerVideoView extends StatefulWidget {
  final MediaStream? stream;
  final bool mirror;
  final PeerVideoViewObjectFit objectFit;

  const PeerVideoView({
    super.key,
    required this.stream,
    this.mirror = false,
    this.objectFit = PeerVideoViewObjectFit.contain,
  });

  @override
  State<PeerVideoView> createState() => _PeerVideoViewState();
}

class _PeerVideoViewState extends State<PeerVideoView> {
  final rtc.RTCVideoRenderer _renderer = rtc.RTCVideoRenderer();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  @override
  void didUpdateWidget(PeerVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _updateStream();
    }
  }

  Future<void> _initRenderer() async {
    await _renderer.initialize();
    if (mounted) {
      setState(() {
        _initialized = true;
      });
      _updateStream();
    }
  }

  void _updateStream() {
    if (!_initialized) return;

    final newSrcObject = widget.stream?.srcObject;
    if (_renderer.srcObject != newSrcObject) {
      _renderer.srcObject = newSrcObject;
    } else if (newSrcObject != null) {
      // Force a re-assignment or notify the renderer?
      // In flutter_webrtc, assigning the same srcObject might be ignored.
      // We'll set it to null and back if we detect we need a hard refresh,
      // but usually the renderer should listen to track changes on the stream.
      _renderer.srcObject = newSrcObject;
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  rtc.RTCVideoViewObjectFit _mapObjectFit(PeerVideoViewObjectFit fit) {
    switch (fit) {
      case PeerVideoViewObjectFit.contain:
        return rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitContain;
      case PeerVideoViewObjectFit.cover:
        return rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || widget.stream == null) {
      return Container(color: Colors.black);
    }
    return rtc.RTCVideoView(
      _renderer,
      mirror: widget.mirror,
      objectFit: _mapObjectFit(widget.objectFit),
    );
  }
}
