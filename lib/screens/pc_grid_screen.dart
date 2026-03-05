import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pc_model.dart';
import '../widgets/live_grid_tile.dart';

class PCGridScreen extends StatefulWidget {
  const PCGridScreen({super.key});

  @override
  State<PCGridScreen> createState() => _PCGridScreenState();
}

class _PCGridScreenState extends State<PCGridScreen> {
  bool _refreshEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F1A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: const Text(
          'Pisonet Live Streams',
          style: TextStyle(
            color: Colors.white70,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _refreshEnabled
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: Colors.cyanAccent,
            ),
            onPressed: () {
              setState(() {
                _refreshEnabled = !_refreshEnabled;
              });
            },
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pcs').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pcs = snapshot.data!.docs
              .map((d) => PC.fromFirestore(d))
              .toList();

          if (pcs.isEmpty) {
            return const Center(
              child: Text(
                'No PCs available',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return GridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: pcs.map((pc) {
              return LiveGridTile(
                pc: pc,
                refreshEnabled: _refreshEnabled,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
