import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/pc_model.dart';
import '../services/webrtc_service.dart';

enum LiveQuality { auto, normal, low }

/// Stream mode
enum StreamMode {
  connecting,
  webrtc,
  mjpeg,
  failed,
}

class LiveViewScreen extends StatefulWidget {
  final PC pc;
  const LiveViewScreen({super.key, required this.pc});

  @override
  State<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends State<LiveViewScreen>
    with WidgetsBindingObserver {
  // ───────── MJPEG ─────────
  Uint8List? _frame;
  StreamSubscription<List<int>>? _sub;
  http.Client? _client;
  final List<int> _buffer = [];

  static const int _maxFps = 8;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _mjpegReconnectTimer;

  // ───────── WEBRTC ─────────
  WebRtcService? _webrtc;
  Timer? _webrtcStartupTimeout;
  Timer? _webrtcHealthTimer;

  // ───────── STATE ─────────
  bool _connectingMjpeg = false;
  LiveQuality _quality = LiveQuality.auto;
  StreamMode _mode = StreamMode.connecting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startWebRtcWithFallback();
  }

  // ─────────────────────────────────────────
  // WebRTC → MJPEG fallback (robust)
  // ─────────────────────────────────────────
  Future<void> _startWebRtcWithFallback() async {
    _cleanupAll();

    setState(() {
      _mode = StreamMode.connecting;
      _frame = null;
    });

    // Hard startup timeout
    _webrtcStartupTimeout = Timer(const Duration(seconds: 15), () {
      if (_mode == StreamMode.connecting) {
        _fallbackToMjpeg();
      }
    });

    final ok = await _tryStartWebRtc();
    if (!mounted) return;

    if (!ok) {
      _fallbackToMjpeg();
      return;
    }

    // WebRTC started, now monitor health
    _webrtcStartupTimeout?.cancel();
    setState(() => _mode = StreamMode.webrtc);

    _webrtcHealthTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (_webrtc == null) return;

        final r = _webrtc!.renderer;

        final noFrames =
            r.videoWidth == 0 ||
            r.videoHeight == 0 ||
            r.srcObject == null;

        if (noFrames) {
          debugPrint("WebRTC unhealthy → fallback to MJPEG");
          _fallbackToMjpeg();
        }
      },
    );
  }

  Future<bool> _tryStartWebRtc() async {
  try {
    _webrtc = WebRtcService();
    await _webrtc!.init();

    final ok = await _webrtc!.start(pcId: widget.pc.id);

    if (!ok) return false;

    await Future.delayed(const Duration(seconds: 5));

    final r = _webrtc!.renderer;

    if (r.videoWidth == 0 || r.videoHeight == 0) {
      return false;
    }

    return true;
  } catch (_) {
    return false;
  }
}

  void _fallbackToMjpeg() {
    if (_mode == StreamMode.mjpeg) return;

    _webrtcStartupTimeout?.cancel();
    _webrtcHealthTimer?.cancel();
    _webrtc?.dispose();
    _webrtc = null;

    setState(() => _mode = StreamMode.mjpeg);
    _startMjpeg();
    debugPrint("Falling back to MJPEG");
  }

  // ─────────────────────────────────────────
  // MJPEG
  // ─────────────────────────────────────────
  String _buildMjpegUrl() {
    final ip = widget.pc.ip;

    if (ip.isEmpty) {
      debugPrint("MJPEG aborted: empty IP");
      return "";
    }

    switch (_quality) {
      case LiveQuality.low:
        return 'http://$ip:5800/mjpeg?mode=low';

      case LiveQuality.normal:
        return 'http://$ip:5800/mjpeg';

      case LiveQuality.auto:
        return widget.pc.isWithinGrace
            ? 'http://$ip:5800/mjpeg'
            : 'http://$ip:5800/mjpeg?mode=low';
    }
  }

  Future<void> _startMjpeg() async {
    final url = _buildMjpegUrl();

    if (_connectingMjpeg || _mode != StreamMode.mjpeg || url.isEmpty) {
      return;
    }
    
    _connectingMjpeg = true;

    try {
      _client?.close();
      _client = http.Client();

      final response =
      await _client!.send(http.Request('GET', Uri.parse(url)));

      _sub?.cancel();
      _sub = response.stream.listen(
        _onChunk,
        onDone: _scheduleMjpegReconnect,
        onError: (_) => _scheduleMjpegReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleMjpegReconnect();
    } finally {
      _connectingMjpeg = false;
    }
  }

  void _scheduleMjpegReconnect() {
    _sub?.cancel();
    _mjpegReconnectTimer?.cancel();

    _mjpegReconnectTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _mode == StreamMode.mjpeg) {
        _startMjpeg();
      }
    });
  }

  void _onChunk(List<int> chunk) {
    if (_mode != StreamMode.mjpeg) return;

    _buffer.addAll(chunk);

    while (true) {
      final start = _findMarker(_buffer, const [0xFF, 0xD8]);
      if (start == -1) return;

      final end = _findMarker(_buffer, const [0xFF, 0xD9], start + 2);
      if (end == -1) return;

      final imageBytes = _buffer.sublist(start, end + 2);
      _buffer.removeRange(0, end + 2);

      final now = DateTime.now();
      if (now.difference(_lastFrameTime).inMilliseconds <
          (1000 ~/ _maxFps)) {
        return;
      }

      _lastFrameTime = now;
      setState(() => _frame = Uint8List.fromList(imageBytes));
    }
  }

  int _findMarker(List<int> data, List<int> marker, [int start = 0]) {
    for (int i = start; i <= data.length - marker.length; i++) {
      bool ok = true;
      for (int j = 0; j < marker.length; j++) {
        if (data[i + j] != marker[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  // ─────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────
  void _cleanupAll() {
    _sub?.cancel();
    _client?.close();
    _mjpegReconnectTimer?.cancel();
    _webrtcStartupTimeout?.cancel();
    _webrtcHealthTimer?.cancel();
    _webrtc?.dispose();

    _sub = null;
    _client = null;
    _webrtc = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupAll();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.pc.name),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_mode) {
      case StreamMode.connecting:
        return const Center(
          child: Text(
            'CONNECTING…',
            style: TextStyle(color: Colors.white54),
          ),
        );

      case StreamMode.webrtc:
        return RTCVideoView(
          _webrtc!.renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        );

      case StreamMode.mjpeg:
        return _frame == null
            ? const Center(
                child: CircularProgressIndicator(strokeWidth: 1.4),
              )
            : Image.memory(_frame!, fit: BoxFit.contain);

      case StreamMode.failed:
        return const Center(
          child: Text(
            'STREAM FAILED',
            style: TextStyle(color: Colors.redAccent),
          ),
        );
    }
  }
}
