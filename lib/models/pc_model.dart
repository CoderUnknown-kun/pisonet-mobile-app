import 'package:cloud_firestore/cloud_firestore.dart';

enum PCConnectionState {
  online,
  reconnecting,
  offline,
}

class PC {
  final String id;
  final String name;
  final String ip;

  final double _cpuUsage;
  final double _ramUsage;
  final double? _temperatureC;
  final DateTime? lastSeen;

  // 🔒 Kept for backward compatibility, no longer trusted
  // ignore: unused_field
  final bool _isOnlineFlag;

  final int sessionSeconds;
  final bool sessionActive;

  final Map<String, dynamic> _rawDailySales;

  PC({
    required this.id,
    required this.name,
    required this.ip,
    required double cpuUsage,
    required double ramUsage,
    double? temperatureC,
    required this.lastSeen,
    required bool isOnline,
    required this.sessionSeconds,
    required this.sessionActive,
    Map<String, dynamic>? rawDailySales,
  })  : _cpuUsage = cpuUsage,
        _ramUsage = ramUsage,
        _temperatureC = temperatureC,
        _isOnlineFlag = isOnline,
        _rawDailySales = rawDailySales ?? {};

  // ======================
  // ONLINE / LAST SEEN
  // ======================
  static const int onlineTimeoutSeconds = 10;
  static const int offlineGraceSeconds = 30;

  PCConnectionState get connectionState {
    if (lastSeen == null) return PCConnectionState.offline;

    final age = DateTime.now().difference(lastSeen!).inSeconds;

    if (age <= onlineTimeoutSeconds) {
      return PCConnectionState.online;
    }
    if (age <= offlineGraceSeconds) {
      return PCConnectionState.reconnecting;
    }
    return PCConnectionState.offline;
  }

  bool get isOnline => connectionState == PCConnectionState.online;

  bool get isWithinGrace =>
      connectionState == PCConnectionState.online ||
      connectionState == PCConnectionState.reconnecting;

  String get lastSeenText {
    if (lastSeen == null) return 'Never';
    final diff = DateTime.now().difference(lastSeen!);

    if (diff.inSeconds < 60) return 'Last seen ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${diff.inDays}d ago';
  }

  // ======================
  // 🔥 TELEMETRY (FIXED)
  // ======================
  double get cpuUsage => isWithinGrace ? _cpuUsage : 0;
  double get ramUsage => isWithinGrace ? _ramUsage : 0;

  // 🌡 keep temp during reconnect, hide only when truly offline
  double? get temperatureC =>
      connectionState == PCConnectionState.offline
          ? null
          : _temperatureC;

  // ======================
  // SESSION
  // ======================
  String get sessionTimeFormatted {
    final m = sessionSeconds ~/ 60;
    final s = sessionSeconds % 60;
    return '${m}m ${s}s';
  }

  double get computedPeso => sessionSeconds / 300;

  // ======================
  // DAILY SALES
  // ======================
  Map<String, dynamic> get rawDailySales => _rawDailySales;

  double get todayPeso {
    final key = _todayKey();
    final day = _rawDailySales[key];
    if (day is Map<String, dynamic>) {
      final seconds = (day['seconds'] ?? 0) as int;
      return seconds / 300;
    }
    return 0;
  }

  // ======================
  // 🧠 OPTIMISTIC ONLINE (UI TRUST)
  // ======================
  bool get isOptimisticallyOnline =>
      connectionState != PCConnectionState.offline;


  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ======================
  // FIRESTORE
  // ======================
  factory PC.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    final session =
        (data?['session'] as Map<String, dynamic>?) ?? {};

    final displayName = (data?['displayName'] as String?)?.trim();

    return PC(
      id: doc.id,
      name: (displayName != null && displayName.isNotEmpty)
          ? displayName
          : doc.id,
      ip: data?['ip'] ?? '',
      cpuUsage: (data?['cpuUsage'] ?? 0).toDouble(),
      ramUsage: (data?['ramUsage'] ?? 0).toDouble(),
      temperatureC: (data?['temperatureC'] as num?)?.toDouble(),
      lastSeen: (data?['lastSeen'] as Timestamp?)?.toDate(),
      isOnline: data?['isOnline'] == true,
      sessionSeconds: (session['seconds'] ?? 0) as int,
      sessionActive: session['active'] == true,
      rawDailySales:
          (data?['dailySales'] as Map<String, dynamic>?) ?? {},
    );
  }
}
