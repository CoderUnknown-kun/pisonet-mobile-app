import 'package:flutter/material.dart';
import '../models/pc_model.dart';
import '../screens/pc_detail_screen.dart';
import '../services/firebase_service.dart';

class PCGridCard extends StatelessWidget {
  final PC pc;

  const PCGridCard({super.key, required this.pc});

  @override
  Widget build(BuildContext context) {
    final state = pc.connectionState;

    final bool isOnline = state == PCConnectionState.online;
    final bool isReconnecting = state == PCConnectionState.reconnecting;
    final bool online = pc.isWithinGrace;

    // Force gauges to zero unless fully ONLINE
    final double cpu =
        isOnline ? pc.cpuUsage.clamp(0.0, 100.0) : 0.0;
    final double ram =
        isOnline ? pc.ramUsage.clamp(0.0, 100.0) : 0.0;

    final Color borderColor = isReconnecting
        ? Colors.amberAccent
        : online
            ? Colors.cyanAccent
            : Colors.white24;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PCDetailScreen(pcId: pc.id),
          ),
        );
      },

      // 👇 LONG PRESS ACTIONS
      onLongPress: () => _showActions(context),

      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        opacity: online ? 1.0 : 0.35,
        child: TweenAnimationBuilder<double>(
          // 🫀 SOFT PULSE (disabled while reconnecting)
          tween: Tween(
            begin: 1.0,
            end: isOnline ? 1.02 : 1.0,
          ),
          duration: const Duration(milliseconds: 1600),
          curve: Curves.easeInOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF111827),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PC NAME
                Text(
                  pc.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // 🔁 RECONNECTING INDICATOR
                if (isReconnecting) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'RECONNECTING…',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // CPU
                _bar('CPU', cpu, isOnline),

                const SizedBox(height: 6),

                // RAM
                _bar('RAM', ram, isOnline),

                const Spacer(),

                // LAST SEEN
                Text(
                  pc.lastSeenText,
                  style: TextStyle(
                    fontSize: 11,
                    color: online ? Colors.white54 : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ACTION SHEET (LONG PRESS)
  // ─────────────────────────────────────────
  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF020617),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pc.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: Colors.cyanAccent,
                ),
                title: const Text(
                  'View details',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PCDetailScreen(pcId: pc.id),
                    ),
                  );
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete PC',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // DELETE CONFIRMATION
  // ─────────────────────────────────────────
  void _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF020617),
        title: const Text(
          'DELETE PC',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          'This will permanently remove this PC.\nThis action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseService.instance.deletePC(pc.id);
    }
  }

  // ─────────────────────────────────────────
  // UI HELPERS
  // ─────────────────────────────────────────
  Widget _bar(String label, double value, bool enabled) {
    final color = enabled ? Colors.cyanAccent : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ${value.toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / 100,
          minHeight: 6,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }
}
