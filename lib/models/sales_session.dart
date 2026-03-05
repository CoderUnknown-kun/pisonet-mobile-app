import 'package:cloud_firestore/cloud_firestore.dart';

class SalesSession {
  final String id;
  final String pcId;
  final DateTime finalizedAt;
  final double peso;
  final int durationSeconds;
  final String endReason;

  SalesSession({
    required this.id,
    required this.pcId,
    required this.finalizedAt,
    required this.peso,
    required this.durationSeconds,
    required this.endReason,
  });

  factory SalesSession.fromFirestore(
    QueryDocumentSnapshot doc,
  ) {
    final d = doc.data() as Map<String, dynamic>;

    return SalesSession(
      id: doc.id,
      pcId: d['pcId'] ?? '',
      finalizedAt:
          (d['finalizedAtLocal'] as Timestamp).toDate(),
      peso: (d['derivedPeso'] ?? 0).toDouble(),
      durationSeconds: (d['durationSeconds'] ?? 0) as int,
      endReason: (d['endReason'] ?? '').toString(),
    );
  }
}
