import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'pc_sales_today_screen.dart';

// ======================================================
// SALES SCREEN
// ======================================================

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        centerTitle: true,
        title: const Text('SALES',
            style: TextStyle(color: Colors.white70)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.greenAccent,
          tabs: const [
            Tab(text: 'TODAY'),
            Tab(text: 'YESTERDAY'),
            Tab(text: 'THIS WEEK'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _SalesTodayTab(),
          _SalesYesterdayTab(),
          _SalesWeekTab(),
        ],
      ),
    );
  }
}

// ================= TODAY =================
class _SalesTodayTab extends StatefulWidget {
  const _SalesTodayTab();

  @override
  State<_SalesTodayTab> createState() => _SalesTodayTabState();
}

class _SalesTodayTabState extends State<_SalesTodayTab> {
  late Future<Map<String, double>> _future;
  late Future<Map<String, String>> _pcNamesFuture;

  DateTime get _start {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _end => _start.add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = FirebaseService.instance.perPcSalesInRange(_start, _end);
    _pcNamesFuture = FirebaseService.instance.pcNameMap();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_future, _pcNamesFuture]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return _errorView(snap.error);
        }

        final sales = snap.data![0] as Map<String, double>;
        final names = snap.data![1] as Map<String, String>;

        final rows = sales.entries
            .where((e) => e.value > 0)
            .map((e) => _PcSales(
                  id: e.key,
                  name: names[e.key] ?? e.key, // ✅ UUID FIX
                  pesos: e.value,
                ))
            .toList();

        final total = rows.fold<double>(0, (s, r) => s + r.pesos);

        if (rows.isEmpty) {
          return const Center(
            child: Text('No sales yet',
                style: TextStyle(color: Colors.white54)),
          );
        }

        return _buildPcList(
          title: 'TOTAL SALES (TODAY)',
          total: total,
          rows: rows,
          onTap: (pc) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PCSalesTodayScreen(
                  pcId: pc.id,
                  pcName: pc.name, // ✅ CLEAN NAME
                  todayPeso: pc.pesos,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _errorView(Object? err) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Error loading sales',
              style: TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),
          Text(
            err?.toString() ?? 'Unknown error',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
// ================= YESTERDAY =================

class _SalesYesterdayTab extends StatefulWidget {
  const _SalesYesterdayTab();

  @override
  State<_SalesYesterdayTab> createState() => _SalesYesterdayTabState();
}

class _SalesYesterdayTabState extends State<_SalesYesterdayTab> {
  late Future<Map<String, double>> _future;
  late Future<Map<String, String>> _pcNamesFuture;

  DateTime get _start {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day)
        .subtract(const Duration(days: 1));
  }

  DateTime get _end => _start.add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = FirebaseService.instance.perPcSalesInRange(_start, _end);
    _pcNamesFuture = FirebaseService.instance.pcNameMap();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_future, _pcNamesFuture]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Text(
              snap.error.toString(),
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final sales = snap.data![0] as Map<String, double>;
        final names = snap.data![1] as Map<String, String>;

        final rows = sales.entries
            .where((e) => e.value > 0)
            .map((e) => _PcSales(
                  id: e.key,
                  name: names[e.key] ?? e.key, // ✅ UUID FIX
                  pesos: e.value,
                ))
            .toList();

        final total = rows.fold<double>(0, (s, r) => s + r.pesos);

        if (rows.isEmpty) {
          return const Center(
            child: Text('No sales yesterday',
                style: TextStyle(color: Colors.white54)),
          );
        }

        return _buildPcList(
          title: 'TOTAL SALES (YESTERDAY)',
          total: total,
          rows: rows,
        );
      },
    );
  }
}

// ================= THIS WEEK =================

class _SalesWeekTab extends StatefulWidget {
  const _SalesWeekTab();

  @override
  State<_SalesWeekTab> createState() => _SalesWeekTabState();
}

class _SalesWeekTabState extends State<_SalesWeekTab> {
  late Future<Map<String, double>> _future;
  late Future<Map<String, String>> _pcNamesFuture;

  DateTime get _startOfWeek {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  DateTime get _end => _startOfWeek.add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future =
        FirebaseService.instance.dailySalesInRange(_startOfWeek, _end);
    _pcNamesFuture = FirebaseService.instance.pcNameMap();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([_future, _pcNamesFuture]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Text(
              snap.error.toString(),
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final sales = snap.data![0] as Map<String, double>;
        final names = snap.data![1] as Map<String, String>;

        if (sales.isEmpty) {
          return const Center(
            child: Text('No sales this week',
                style: TextStyle(color: Colors.white54)),
          );
        }

        final total = sales.values.fold<double>(0, (a, b) => a + b);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _glass(
              Column(
                children: [
                  const Text('TOTAL SALES (THIS WEEK)',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 10),
                  Text(
                    '₱${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...sales.entries.map(
              (e) => _glass(
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        names[e.key] ?? e.key, // ✅ UUID FIX
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '₱${e.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ================= UI =================

Widget _buildPcList({
  required String title,
  required double total,
  required List<_PcSales> rows,
  void Function(_PcSales pc)? onTap,
}) {
  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _glass(
        Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 10),
            Text('₱${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      const SizedBox(height: 24),
      ...rows.map(
        (pc) => GestureDetector(
          onTap: onTap != null ? () => onTap(pc) : null,
          child: _glass(
            Row(
              children: [
                Expanded(
                    child: Text(pc.name,
                        style:
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                Text('₱${pc.pesos.toStringAsFixed(2)}',
                    style:
                        const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    ],
  );
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

class _PcSales {
  final String id;
  final String name;
  final double pesos;

  _PcSales({
    required this.id,
    required this.name,
    required this.pesos,
  });
}
