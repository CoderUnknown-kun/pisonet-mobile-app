import 'package:flutter/material.dart';
import '../models/pc_model.dart';

class PCSalesHistoryScreen extends StatelessWidget {
  final PC pc;

  const PCSalesHistoryScreen({super.key, required this.pc});

  bool _isFutureDate(String date) {
    try {
      final parts = date.split('-');
      if (parts.length != 3) return false;
      final d = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      final today = DateTime.now();
      return d.isAfter(DateTime(today.year, today.month, today.day));
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = pc.rawDailySales.entries
        .where((e) => !_isFutureDate(e.key)) // 🔒 FILTER FUTURE
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${pc.name} – HISTORY',
          style: const TextStyle(
            color: Colors.white70,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download, color: Colors.cyanAccent),
            onPressed: () => _exportCSV(context),
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text('No sales data yet',
                  style: TextStyle(color: Colors.white54)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (_, i) {
                final date = entries[i].key;
                final data = entries[i].value as Map<String, dynamic>;

                final pesos = (data['pesos'] ?? 0).toDouble();
                final seconds = (data['seconds'] ?? 0) as int;

                return _glass(
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₱${pesos.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_formatTime(seconds),
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  Widget _glass(Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B0F1A), Color(0xFF111827)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }

  void _exportCSV(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Pesos,Seconds');

    pc.rawDailySales.forEach((date, data) {
      if (_isFutureDate(date)) return;
      buffer.writeln(
          '$date,${data['pesos'] ?? 0},${data['seconds'] ?? 0}');
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        title: const Text('CSV EXPORT',
            style: TextStyle(color: Colors.cyanAccent)),
        content: SingleChildScrollView(
          child: Text(buffer.toString(),
              style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 12)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE')),
        ],
      ),
    );
  }
}
