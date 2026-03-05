import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/pc_model.dart';
import '../screens/live_view_screen.dart';
import '../services/firebase_service.dart';
import '../services/webrtc_service.dart';

enum StreamMode {
  connecting,
  webrtc,
  mjpeg,
  failed,
}

class LiveGridTile extends StatefulWidget {
  final PC pc;
  final bool refreshEnabled;

  const LiveGridTile({
    super.key,
    required this.pc,
    required this.refreshEnabled,
  });

  @override
  State<LiveGridTile> createState() => _LiveGridTileState();
}

class _LiveGridTileState extends State<LiveGridTile> {
  // ─────────────────────────────
  // STREAM STATE
  // ─────────────────────────────
  StreamMode _mode = StreamMode.connecting;

  Timer? _webrtcTimeout;
  WebRtcService? _webrtc;
  RTCVideoRenderer? _renderer;

  Uint8List? _frame;

  StreamSubscription<List<int>>? _sub;
  http.Client? _client;
  final List<int> _buffer = [];

  static const int _maxFps = 3;

  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastSuccessFrame;

  bool _visible = true;
  bool _connecting = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant LiveGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    final online = widget.pc.isOptimisticallyOnline && widget.refreshEnabled;

    if (!online) {
      _stop();
      setState(() => _frame = null);
    } else if (oldWidget.pc.id != widget.pc.id ||
        oldWidget.pc.ip != widget.pc.ip ||
        oldWidget.refreshEnabled != widget.refreshEnabled) {
      _stop();
      _start();
    }
  }

  // ─────────────────────────────
  // STREAM START
  // ─────────────────────────────
  void _start() async {
  if (!widget.refreshEnabled || !widget.pc.isOptimisticallyOnline) return;
  if (_connecting) return;

  _connecting = true;

  setState(() {
    _mode = StreamMode.connecting;
    _frame = null;
  });

  // ⏱️ WebRTC startup fuse (DEFENSIVE UX GUARD)
  _webrtcTimeout?.cancel();
  _webrtcTimeout = Timer(const Duration(seconds: 6), () {
    if (_mode == StreamMode.connecting) {
      _fallbackToMjpeg();
    }
  });

  final ok = await _tryWebRtc();
  if (!mounted) return;

  if (ok && _renderer != null) {
    _webrtcTimeout?.cancel();
    setState(() => _mode = StreamMode.webrtc);
  } else {
    _fallbackToMjpeg();
  }

  _connecting = false;
}

  Future<bool> _tryWebRtc() async {
    try {
      _webrtc = WebRtcService();
      await _webrtc!.init();

      final success = await _webrtc!.start(pcId: widget.pc.id);
      if (!success) return false;

      _renderer = _webrtc!.renderer;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────
  // MJPEG FALLBACK (YOUR ORIGINAL LOGIC)
  // ─────────────────────────────
  void _startMjpeg() async {
    setState(() => _mode = StreamMode.mjpeg);

    _client?.close();
    _client = http.Client();

    try {
      final url = Uri.parse('http://${widget.pc.ip}:5800/mjpeg');
      final request = http.Request('GET', url);

      final streamedResponse = await _client!.send(request).timeout(
        const Duration(seconds: 6),
      );

      _sub?.cancel();
      _retryCount = 0;
      _cancelRetryTimer();

      _sub = streamedResponse.stream.listen(
        _onChunk,
        onDone: _handleStreamError,
        onError: (_) => _handleStreamError(),
        cancelOnError: true,
      );
    } catch (_) {
      _handleStreamError();
    }
  }

  void _fallbackToMjpeg() {
  if (!mounted) return;
  if (_mode == StreamMode.mjpeg) return;

  _webrtcTimeout?.cancel();

  _webrtc?.dispose();
  _webrtc = null;
  _renderer?.dispose();
  _renderer = null;

  setState(() {
    _mode = StreamMode.mjpeg;
  });

  _startMjpeg();
}


  void _handleStreamError() {
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
    _buffer.clear();

    setState(() {
      _frame = null;
    });

    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryCount++;
    final capped = _retryCount.clamp(0, 6);
    final wait = (1 << capped).clamp(2, 60);

    _cancelRetryTimer();
    _retryTimer = Timer(Duration(seconds: wait), () {
      if (mounted && widget.refreshEnabled) _start();
    });

    if (mounted) setState(() {});
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _onChunk(List<int> chunk) {
    if (!_visible || !mounted || _mode != StreamMode.mjpeg) return;

    _buffer.addAll(chunk);

    while (true) {
      final start = _findMarker([0xFF, 0xD8]);
      if (start == -1) return;

      final end = _findMarker([0xFF, 0xD9], start + 2);
      if (end == -1) return;

      final frameBytes = _buffer.sublist(start, end + 2);
      _buffer.removeRange(0, end + 2);

      final now = DateTime.now();
      if (now.difference(_lastFrame).inMilliseconds <
          (1000 ~/ _maxFps)) {
        return;
      }

      _lastFrame = now;

      setState(() {
        _frame = Uint8List.fromList(frameBytes);
        _lastSuccessFrame = DateTime.now();
        _retryCount = 0;
        _cancelRetryTimer();
      });
    }
  }

  int _findMarker(List<int> marker, [int start = 0]) {
    for (int i = start; i <= _buffer.length - marker.length; i++) {
      bool ok = true;
      for (int j = 0; j < marker.length; j++) {
        if (_buffer[i + j] != marker[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  void _stop() {
  _webrtcTimeout?.cancel();
  _retryTimer?.cancel();

  _sub?.cancel();
  _client?.close();

  _webrtc?.dispose();
  _renderer?.dispose();

  _sub = null;
  _client = null;
  _webrtc = null;
  _renderer = null;
  _frame = null;
  _retryCount = 0;
}

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  // ─────────────────────────────
  // UI
  // ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    final online = widget.pc.isOptimisticallyOnline && widget.refreshEnabled;


    final noFrame = _frame == null && _renderer == null;
    final recentlyHadFrame = _lastSuccessFrame != null &&
        DateTime.now().difference(_lastSuccessFrame!).inSeconds < 6;

    final isReconnecting =
        online && noFrame && (_connecting || _retryCount > 0 || !recentlyHadFrame);

    return VisibilityDetector(
      key: ValueKey(widget.pc.id),
      onVisibilityChanged: (info) {
        _visible = info.visibleFraction > 0.2;
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveViewScreen(pc: widget.pc),
            ),
          );
        },
        onLongPress: () => _showQuickActions(context),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: online ? 1.0 : 0.45,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: const Color(0xFF020617),
              child: Stack(
                children: [
                  Positioned.fill(child: _buildStream(online)),

                  if (isReconnecting)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _reconnectingBadge(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStream(bool online) {
    if (!online) {
      return _offlineState(false);
    }

    if (_mode == StreamMode.webrtc && _renderer != null) {
      return RTCVideoView(
        _renderer!,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    if (_mode == StreamMode.mjpeg && _frame != null) {
      return Image.memory(
        _frame!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return _offlineState(true);
  }

  Widget _reconnectingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amberAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.28)),
      ),
      child: Row(
        children: const [
          Icon(Icons.sync, size: 14, color: Colors.amberAccent),
          SizedBox(width: 8),
          Text(
            'RECONNECTING…',
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────
  void _showQuickActions(BuildContext context) {
    if (!widget.pc.isOptimisticallyOnline) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.pc.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 18),

              _actionTile(
                icon: Icons.lock,
                label: 'Lock PC',
                color: Colors.orangeAccent,
                onTap: () {
                  Navigator.pop(context);
                  FirebaseService.instance.sendCommand(
                    pcId: widget.pc.id,
                    type: 'lock',
                  );
                },
              ),

              _actionTile(
                icon: Icons.restart_alt,
                label: 'Restart PC',
                color: Colors.cyanAccent,
                onTap: () {
                  Navigator.pop(context);
                  FirebaseService.instance.sendCommand(
                    pcId: widget.pc.id,
                    type: 'restart',
                  );
                },
              ),

              _actionTile(
                icon: Icons.power_settings_new,
                label: 'Shutdown PC',
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  FirebaseService.instance.sendCommand(
                    pcId: widget.pc.id,
                    type: 'shutdown',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: onTap,
    );
  }

  Widget _offlineState(bool online) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.pc.name,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            online ? 'NO SIGNAL' : 'PC OFFLINE',
            style: TextStyle(
              color: online ? Colors.orangeAccent : Colors.white38,
              letterSpacing: 1.3,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
