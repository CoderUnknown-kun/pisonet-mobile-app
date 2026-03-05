import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PCSalesTodayScreen extends StatelessWidget {
  final String pcId;
  final String pcName;
  final double todayPeso;

  const PCSalesTodayScreen({
    super.key,
    required this.pcId,
    required this.pcName,
    required this.todayPeso,
  });

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _endOfToday =>
      _startOfToday.add(const Duration(days: 1));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        centerTitle: true,
        title: Text(
          '$pcName — Today',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('companies')
              .doc('mlsn_internal')
              .collection('pcs')
              .doc(pcId)
              .collection('sessions')
              .where(
                'finalizedAtLocal',
                isGreaterThanOrEqualTo: _startOfToday,
              )
              .where(
                'finalizedAtLocal',
                isLessThan: _endOfToday,
              )
              .orderBy('finalizedAtLocal', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "No sessions recorded today",
                  style: TextStyle(color: Colors.white38),
                ),
              );
            }

            double totalPeso = 0;
            for (final d in snap.data!.docs) {
              totalPeso += (d['derivedPeso'] ?? 0).toDouble();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TODAY TOTAL',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  '₱${totalPeso.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'SESSIONS',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: snap.data!.docs.length,
                    itemBuilder: (_, i) {
                      final d = snap.data!.docs[i];
                      final seconds =(d['durationSeconds'] ?? 0) as int;
                      final peso = (d['derivedPeso'] ?? 0).toDouble();
                      final ts = (d['finalizedAtLocal'] as Timestamp?)?.toDate() ?? DateTime.now();

                      return ListTile(
                        leading: const Icon(
                          Icons.history,
                          color: Colors.white38,
                        ),
                        title: Text(
                          '${_time(ts)}   ${_fmt(seconds)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          (d['endReason'] ?? '').toString(),
                          style: const TextStyle(color: Colors.white38),
                        ),
                        trailing: Text(
                          '₱${peso.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}m ${sec}s';
  }
  String _time(DateTime t) {
  final h = t.hour > 12 ? t.hour - 12 : t.hour == 0 ? 12 : t.hour;
  final m = t.minute.toString().padLeft(2, '0');
  final ap = t.hour >= 12 ? 'PM' : 'AM';
  return '${h.toString().padLeft(2, ' ')}:$m $ap';
}
}
