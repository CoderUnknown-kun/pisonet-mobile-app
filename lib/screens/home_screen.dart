import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/pc_model.dart';
import '../widgets/pc_grid_card.dart';
import 'add_pc_screen.dart';
import 'pc_grid_screen.dart';
import 'sales_screen.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 🔄 Refresh trigger
  int _refreshKey = 0;

  @override
void initState() {
  super.initState();
  // 🔄 Reset RTDB listeners & cache on app open
  FirebaseService.instance.resetTelemetry();
}

  Future<void> _refresh() async {
    setState(() {
      _refreshKey++;
    });

    // short delay for UX smoothness
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pisonet PCs'),
        centerTitle: true,
        actions: [
          // 🌗 THEME TOGGLE
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeModeNotifier.value =
                  themeModeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
          ),

          // 📊 SALES SCREEN
          IconButton(
            tooltip: 'Sales',
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SalesScreen(),
                ),
              );
            },
          ),

          // 🧩 LIVE GRID
          IconButton(
            tooltip: 'Live Grid',
            icon: const Icon(Icons.grid_view),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PCGridScreen(),
                ),
              );
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPCScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),

      body: RefreshIndicator(
        onRefresh: _refresh,
        child: StreamBuilder<List<PC>>(
          key: ValueKey(_refreshKey),
          stream: FirebaseService.instance.pcStream(),
          builder: (context, snapshot) {
            // 🚀 DO NOT BLOCK UI ON FIRESTORE
            final pcs = snapshot.data ?? const <PC>[];

            if (pcs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No PCs registered',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              );
            }

            return GridView.count(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: pcs.map((pc) {
                return PCGridCard(pc: pc);
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
