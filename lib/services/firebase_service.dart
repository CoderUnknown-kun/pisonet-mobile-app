import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/pc_model.dart';
import '../models/sales_session.dart';
import 'admin_auth.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseReference _telemetryRoot =
      FirebaseDatabase.instance.ref('telemetry');

  static const String _companyId = 'mlsn_internal';
  CollectionReference<Map<String, dynamic>> _pcsRef() {
  return _db
      .collection('companies')
      .doc(_companyId)
      .collection('pcs');
}

// ===============================
// 🔥 TELEMETRY STATE
// ===============================
final Map<String, Map<String, double?>> _latestTelemetry = {};
final Map<String, StreamController<Map<String, double?>>> _controllers = {};
final Map<String, StreamSubscription<DatabaseEvent>> _subs = {};

// ===============================
// 🔄 RESET TELEMETRY (APP RESTART FIX)
// ===============================
void resetTelemetry() {
  for (final sub in _subs.values) {
    sub.cancel();
  }
  _subs.clear();
  _controllers.clear();
  _latestTelemetry.clear();
}

  
  // ===============================
  // 🔥 ATTACH RTDB LISTENER (ONCE)
  // ===============================
  void _attachTelemetry(String pcId) {
    if (_subs.containsKey(pcId)) return;

    final controller = _controllers.putIfAbsent(
      pcId,
      () => StreamController<Map<String, double?>>.broadcast(),
    );

    _subs[pcId] = _telemetryRoot.child(pcId).onValue.listen((event) {
      final raw = event.snapshot.value;

      if (raw is Map) {
        final data = <String, double?>{
          'cpu': (raw['cpu'] as num?)?.toDouble(),
          'ram': (raw['ram'] as num?)?.toDouble(),
          'temp': (raw['temp'] as num?)?.toDouble(),
        };

        _latestTelemetry[pcId] = data;
        controller.add(data);
      }
    });
  }

  // ===============================
  // 🔥 PUBLIC HOT STREAM
  // ===============================
  Stream<Map<String, double?>> telemetryStream(String pcId) {
    _attachTelemetry(pcId);

    final controller = _controllers[pcId]!;

    if (_latestTelemetry.containsKey(pcId)) {
      Future.microtask(() {
        controller.add(_latestTelemetry[pcId]!);
      });
    }

    return controller.stream;
  }

  // ===============================
  // STREAM ALL PCs (STATUS)
  // ===============================
  Stream<List<PC>> pcStream() {
  return _pcsRef().snapshots().map((snap) {
    return snap.docs.map((doc) {
      final base = PC.fromFirestore(doc);

      // 🔑 SINGLE SOURCE OF TRUTH
      final telemetryKey =
      (doc.data()['pcId'] ?? doc.id).toString();

      _attachTelemetry(telemetryKey);
      final t = _latestTelemetry[telemetryKey];

      return PC(
        id: base.id,
        name: base.name,
        ip: base.ip,
        cpuUsage: t?['cpu'] ?? 0,
        ramUsage: t?['ram'] ?? 0,
        temperatureC: t?['temp'],
        lastSeen: base.lastSeen,
        isOnline: base.isOnline,
        sessionSeconds: base.sessionSeconds,
        sessionActive: base.sessionActive,
        rawDailySales: base.rawDailySales,
      );
    }).toList();
  });
}


  // ===============================
  // STREAM SINGLE PC
  // ===============================
  Stream<PC?> pcById(String id) {
  return _pcsRef().doc(id).snapshots().map((doc) {
    if (!doc.exists) return null;

    final base = PC.fromFirestore(doc);

    // 🔑 SAME RESOLUTION LOGIC
    final telemetryKey =
    (doc.data()?['pcId'] ?? doc.id).toString();

    _attachTelemetry(telemetryKey);
    final t = _latestTelemetry[telemetryKey];

    return PC(
      id: base.id,
      name: base.name,
      ip: base.ip,
      cpuUsage: t?['cpu'] ?? 0,
      ramUsage: t?['ram'] ?? 0,
      temperatureC: t?['temp'],
      lastSeen: base.lastSeen,
      isOnline: base.isOnline,
      sessionSeconds: base.sessionSeconds,
      sessionActive: base.sessionActive,
      rawDailySales: base.rawDailySales,
    );
  });
}

  // ===============================
// ADD PC (OPTIMIZED)
// ===============================
Future<void> addPC({
  required String id,
  required String name,
  required String ip,
  String? note,
}) async {
  await _pcsRef().doc(id).set({
    'pcId': id, // must match agent PC_ID
    'name': name,
    'ip': ip,
    'note': note,
    'isOnline': false,
    'lastSeen': FieldValue.serverTimestamp(),
    'session': {
      'seconds': 0,
      'active': false,
    },
  }, SetOptions(merge: true));
}

  // ===============================
  // SEND COMMAND
  // ===============================
  Future<String> sendCommand({
    required String pcId,
    required String type,
    Map<String, dynamic>? payload,
  }) async {
    await AdminAuth.ensureAdminLoggedIn();

    final pcRef = _pcsRef().doc(pcId);
    final pcSnap = await pcRef.get();

    if (!pcSnap.exists) throw Exception('PC does not exist');
    if (pcSnap.data()?['isOnline'] != true) {
      throw Exception('PC is offline');
    }

    final now = Timestamp.now();
    final ref = pcRef.collection('commands').doc();

    await ref.set({
      'type': type,
      'issuedBy': 'mobile',
      'status': 'pending',
      'createdAt': now,
      'expiresAt': Timestamp.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch + 60000,
      ),
      if (payload != null) 'payload': payload,
    });

    return ref.id;
  }

  Future<void> deletePC(String pcId) async {
    await _pcsRef().doc(pcId).delete();
  }

// ===============================
// FINALIZE SESSION (WRITE SALES)
// ===============================

  // =====================================================
  // 🔥 SALES — BILLING GRADE (PER-PC SUBCOLLECTION QUERIES)
  // =====================================================
  //
  // NOTE:
  // We intentionally avoid collectionGroup('sessions') here to remove the
  // need for a collection-group composite index. Instead we fetch sessions
  // from each PC's /pcs/{pcId}/sessions subcollection and combine results.
  // This costs N queries (N = number of PCs) but avoids the index requirement.
  //
  Future<List<SalesSession>> salesSessionsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final pcSnap = await _pcsRef().get();

    // For each PC, query its sessions subcollection within the date range.
    final futures = pcSnap.docs.map((pcDoc) {
      return pcDoc.reference
          .collection('sessions')
          .where('finalizedAtLocal', isGreaterThanOrEqualTo: start)
          .where('finalizedAtLocal', isLessThan: end)
          .get();
    }).toList();

    final results = await Future.wait(futures);

    // flatten all docs and convert to SalesSession
    final allDocs = results.expand((q) => q.docs);
    final sessions = allDocs.map(SalesSession.fromFirestore).toList();

    // filter out non-positive pesos for billing-grade
    return sessions.where((s) => s.peso > 0).toList();
  }

  Future<Map<String, double>> perPcSalesInRange(
    DateTime start,
    DateTime end,
  ) async {
    final list = await salesSessionsInRange(start, end);
    final map = <String, double>{};

    for (final s in list) {
      map[s.pcId] = (map[s.pcId] ?? 0) + s.peso;
    }

    return map;
  }

  Future<Map<String, double>> dailySalesInRange(
    DateTime start,
    DateTime end,
  ) async {
    final list = await salesSessionsInRange(start, end);
    final map = <String, double>{};

    for (final s in list) {
      final d = s.finalizedAt;
      final key = '${_month(d.month)} ${d.day} (${_day(d.weekday)})';
      map[key] = (map[key] ?? 0) + s.peso;
    }

    return map;
  }
// ===============================
// 🔹 PC NAME LOOKUP (FOR SALES UI)
// ===============================
Future<Map<String, String>> pcNameMap() async {
  final snap = await _pcsRef().get();
  final map = <String, String>{};

  for (final d in snap.docs) {
    final data = d.data();
    final name = (data['displayName'] ??
            data['name'] ??
            d.id)
        .toString()
        .trim();

    map[d.id] = name.isEmpty ? d.id : name;
  }

  return map;
}

  String _day(int w) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];

  String _month(int m) => [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ][m - 1];
}
