import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WebRtcService {
  RTCPeerConnection? _pc;
  MediaStream? _remoteStream;

  StreamSubscription? _answerSub;
  StreamSubscription? _iceSub;

  final _renderer = RTCVideoRenderer();

  // Add these fields to WebRtcService class:
  bool _remoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];
  String? _pcId;

  RTCVideoRenderer get renderer => _renderer;

  Future<void> init() async {
    await _renderer.initialize();
  }

  Future<bool> start({required String pcId}) async {
  try {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    await _pc?.close();
    await _answerSub?.cancel();
    await _iceSub?.cancel();

    _pc = await createPeerConnection(config);

    final completer = Completer<bool>();

    _pc!.onConnectionState = (state) {
      debugPrint("WebRTC state: $state");

      if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }

      if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state ==
              RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        _pc?.close();
      }
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _renderer.srcObject = _remoteStream;
      }
    };

// Then inside start({ required String pcId })
_pcId = pcId;
_remoteDescriptionSet = false;
_pendingCandidates.clear();

// LOCAL ICE: send to agent (/webrtc/candidates/in)
_pc!.onIceCandidate = (RTCIceCandidate? candidate) async {
  if (candidate == null) return;
  try {
    await FirebaseFirestore.instance
      .collection('pcs')
      .doc(_pcId)
      .collection('webrtc')
      .doc('candidates')
      .collection('in')
      .add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'ts': FieldValue.serverTimestamp(),
      });
  } catch (e) {
    debugPrint('Failed to upload local ICE: $e');
  }
};

// ICE listener from agent (remote candidates)
_iceSub = FirebaseFirestore.instance
    .collection('pcs')
    .doc(pcId)
    .collection('webrtc')
    .doc('candidates')
    .collection('out')
    .snapshots()
    .listen((snap) {
  for (final d in snap.docChanges) {
    // only process added documents
    if (d.type == DocumentChangeType.added) {
      final data = d.doc.data();
      if (data == null) continue;
      final cand = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );

      if (_remoteDescriptionSet) {
        _pc?.addCandidate(cand);
      } else {
        _pendingCandidates.add(cand);
      }
    }
  }
});

// CREATE OFFER
final offer = await _pc!.createOffer();
await _pc!.setLocalDescription(offer);

// SEND OFFER TO FIRESTORE
await FirebaseFirestore.instance
    .collection('pcs')
    .doc(pcId)
    .collection('webrtc')
    .doc('offer')
    .set({
  'sdp': offer.sdp,
  'type': offer.type,
  'ts': FieldValue.serverTimestamp(),
});

// LISTEN FOR ANSWER
_answerSub = FirebaseFirestore.instance
    .collection('pcs')
    .doc(pcId)
    .collection('webrtc')
    .doc('answer')
    .snapshots()
    .listen((snap) async {
  if (!snap.exists) return;
  final data = snap.data();
  if (data == null) return;

  await _pc!.setRemoteDescription(
    RTCSessionDescription(data['sdp'], data['type']),
  );

  _remoteDescriptionSet = true;

  // flush buffered remote ICE
  for (final c in _pendingCandidates) {
    try {
      await _pc!.addCandidate(c);
    } catch (e) {
      debugPrint('Error adding buffered candidate: $e');
    }
  }
  _pendingCandidates.clear();
});

    // RETURN FUTURE THAT WAITS FOR REAL RESULT
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint("WebRTC timeout → fallback");
        _pc?.close();
        return false;
      },
    );
  } catch (_) {
    return false;
  }
}

  void dispose() {
  _answerSub?.cancel();
  _iceSub?.cancel();
  _renderer.dispose();
  _remoteStream?.dispose();
  _pc?.close();
}
}
