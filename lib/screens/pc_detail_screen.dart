import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // haptic
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pc_model.dart';
import '../services/firebase_service.dart';
import '../widgets/command_button.dart';
import '../utils/command_banner_controller.dart';
import '../widgets/command_banner.dart';
import 'live_view_screen.dart';

class PCDetailScreen extends StatelessWidget {
  final String pcId;

  const PCDetailScreen({super.key, required this.pcId});

  // ================= SALES (FIRESTORE) =================

  Stream<double> _todaySalesStream(String pcId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return FirebaseFirestore.instance
        .collection('companies')
        .doc('mlsn_internal')
        .collection('pcs')
        .doc(pcId)
        .collection('sessions')
        .where('finalizedAtLocal', isGreaterThanOrEqualTo: startOfDay)
        .snapshots()
        .map((snap) {
      double total = 0;
      for (final doc in snap.docs) {
        total += (doc['derivedPeso'] ?? 0).toDouble();
      }
      return total;
    });
  }

  String _lastSeenText(DateTime? lastSeen) {
    if (lastSeen == null) return 'Never seen';
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inSeconds < 60) return 'Last seen ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    return 'Last seen ${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseService.instance;

    return StreamBuilder<PC?>(
      stream: fs.pcById(pcId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final pc = snapshot.data!;
        final state = pc.connectionState;

        final bool isOnline = state == PCConnectionState.online;
        final bool isReconnecting =
            state == PCConnectionState.reconnecting;

        // ================= MAIN STATUS =================
        final String statusText;
        final Color statusColor;

        if (isReconnecting) {
          statusText = 'RECONNECTING…';
          statusColor = Colors.amberAccent;
        } else if (!isOnline) {
          statusText = 'OFFLINE';
          statusColor = Colors.grey;
        } else if (pc.sessionActive) {
          statusText = 'ACTIVE';
          statusColor = Colors.greenAccent;
        } else {
          statusText = 'STOPPED';
          statusColor = Colors.orangeAccent;
        }

        final double sessionPeso = pc.sessionSeconds / 300;

        // ✅ AGENT-AWARE SALE STATUS
        final bool saleRunning = pc.sessionActive && isOnline;
        final String saleStatusText =
            saleRunning ? 'RUNNING' : 'STOPPED';
        final Color saleStatusColor =
            saleRunning ? Colors.greenAccent : Colors.orangeAccent;

        return Scaffold(
          backgroundColor: const Color(0xFF020617),
          appBar: AppBar(
            backgroundColor: const Color(0xFF020617),
            elevation: 0,
            centerTitle: true,
            title: Text(
              pc.name,
              style: const TextStyle(
                color: Colors.white70,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDelete(context, fs, pc.id),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _statusBar(pc, statusText, statusColor),
                const SizedBox(height: 16),

                // ================= LIVE TELEMETRY =================

                AnimatedOpacity(
                  opacity: isOnline && !isReconnecting ? 1.0 : 0.45,
                  duration: const Duration(milliseconds: 300),
                  child: StreamBuilder<Map<String, double?>>(
                    stream: fs.telemetryStream(pcId),
                    builder: (context, snap) {
                      final bool gaugesEnabled =
                          isOnline && !isReconnecting;

                      final data = snap.data;

                      double cpu = 0.0;
                      double ram = 0.0;
                      double? temp;

                      if (gaugesEnabled && data != null) {
                        cpu = _toDoubleSafe(data['cpu']);
                        ram = _toDoubleSafe(data['ram']);
                        final t = data['temp'];
                        temp = t == null ? null : _toDoubleSafe(t);
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _gauge(
                              label: 'CPU USAGE',
                              value: cpu,
                              color: Colors.cyanAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _gauge(
                              label: 'RAM USAGE',
                              value: ram,
                              color: Colors.purpleAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _tempGauge(temp)),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                _glass(
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.cyanAccent),
                      const SizedBox(width: 10),
                      Text(
                        pc.sessionTimeFormatted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Session ₱${sessionPeso.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!isOnline) ...[
                  const SizedBox(height: 10),
                  Text(
                    _lastSeenText(pc.lastSeen),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ================= SALE SUMMARY =================

                _glass(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SALE SUMMARY',
                        style: TextStyle(
                          color: Colors.white70,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<double>(
                        stream: _todaySalesStream(pc.id),
                        builder: (context, snap) {
                          final total = snap.data ?? 0;
                          return _row(
                            'Today total',
                            '₱${total.toStringAsFixed(0)}',
                            color: Colors.greenAccent,
                          );
                        },
                      ),
                      _row('Rate', '₱1 / 5 minutes'),
                      _row(
                        'Status',
                        saleStatusText,
                        color: saleStatusColor,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'CONTROLS',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                IgnorePointer(
                  ignoring: !isOnline || isReconnecting,
                  child: Opacity(
                    opacity: isOnline && !isReconnecting ? 1 : 0.35,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        CommandButton(
                          icon: Icons.lock,
                          label: 'Lock',
                          color: Colors.orangeAccent,
                          onPressed: () =>
                              _confirmAction(context, fs, pc.id, 'lock'),
                        ),
                        CommandButton(
                          icon: Icons.restart_alt,
                          label: 'Restart',
                          color: Colors.cyanAccent,
                          onPressed: () =>
                              _confirmAction(context, fs, pc.id, 'restart'),
                        ),
                        CommandButton(
                          icon: Icons.power_settings_new,
                          label: 'Shutdown',
                          color: Colors.redAccent,
                          onPressed: () =>
                              _confirmAction(context, fs, pc.id, 'shutdown'),
                        ),
                        CommandButton(
                          icon: Icons.stop_circle,
                          label: 'End Session',
                          color: Colors.deepOrangeAccent,
                          onPressed: () =>
                              _confirmAction(context, fs, pc.id, 'end_session'),
                        ),
                        CommandButton(
                          icon: Icons.message,
                          label: 'Message',
                          color: Colors.greenAccent,
                          onPressed: () =>
                              _showMessageDialog(context, fs, pc.id),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                _glass(
                  ElevatedButton.icon(
                    icon: const Icon(Icons.live_tv),
                    label: const Text('OPEN LIVE VIEW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isOnline && !isReconnecting
                              ? Colors.black
                              : Colors.black54,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: isOnline && !isReconnecting
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveViewScreen(pc: pc),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    try {
      return (v as num).toDouble();
    } catch (_) {
      return 0.0;
    }
  }

  // ================= ACTION EXECUTION =================

  Future<void> _confirmAction(
    BuildContext context,
    FirebaseService fs,
    String pcId,
    String type,
  ) async {
    final cfg = _confirmConfig(type);

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: _glass(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(cfg.icon, color: cfg.color, size: 42),
              const SizedBox(height: 14),
              Text(
                cfg.title,
                style: TextStyle(
                  color: cfg.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                cfg.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cfg.color,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('CONFIRM'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      HapticFeedback.lightImpact();
      try {
        await fs.sendCommand(pcId: pcId, type: type);

        if (context.mounted) {
          CommandBannerController.show(
            context,
            command: type,
            status: CommandStatus.sent,
          );
        }
      } catch (_) {
        if (context.mounted) {
          CommandBannerController.show(
            context,
            command: type,
            status: CommandStatus.error,
          );
        }
      }
    }
  }

  void _showMessageDialog(
      BuildContext context, FirebaseService fs, String pcId) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: _glass(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SEND MESSAGE',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter message...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isNotEmpty) {
                          await fs.sendCommand(
                            pcId: pcId,
                            type: 'message',
                            payload: {'text': text},
                          );
                          if (context.mounted) {
                            CommandBannerController.show(
                              context,
                              command: 'message',
                              status: CommandStatus.sent,
                            );
                          }
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('SEND'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
  BuildContext context,
  FirebaseService fs,
  String pcId,
) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: _glass(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_forever,
              color: Colors.redAccent,
              size: 42,
            ),
            const SizedBox(height: 14),
            const Text(
              'DELETE PC',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will permanently remove this PC.\nThis action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Colors.white38,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'DELETE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (ok == true) {
    HapticFeedback.mediumImpact();
    await fs.deletePC(pcId);
    if (context.mounted) Navigator.pop(context);
  }
}

  Widget _statusBar(PC pc, String text, Color color) => _glass(
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(pc.ip, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );

  Widget _glass(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
          color: const Color(0xFF0B0F1A),
        ),
        child: child,
      );

  Widget _gauge({
    required String label,
    required double value,
    required Color color,
  }) =>
      _glass(
        Column(
          children: [
            SizedBox(
              height: 90,
              width: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: (value.clamp(0.0, 100.0)) / 100.0,
                    strokeWidth: 7,
                    color: color,
                    backgroundColor: const Color(0xFF1F2933),
                  ),
                  Text(
                    '${value.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );

  Widget _tempGauge(double? tempC) {
    final bool available = tempC != null;
    final double value = tempC ?? 0;

    Color color;
    if (!available) {
      color = Colors.white24;
    } else if (value < 65) {
      color = Colors.greenAccent;
    } else if (value < 80) {
      color = Colors.amberAccent;
    } else {
      color = Colors.redAccent;
    }

    return _glass(
      Column(
        children: [
          SizedBox(
            height: 90,
            width: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: available ? (value.clamp(0, 100) / 100) : 0,
                  strokeWidth: 7,
                  color: color,
                  backgroundColor: const Color(0xFF1F2933),
                ),
                Text(
                  available ? '${value.toStringAsFixed(0)}°C' : '--°C',
                  style: TextStyle(
                    color: available ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('TEMP', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(k, style: const TextStyle(color: Colors.white54)),
            const Spacer(),
            Text(
              v,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ================= CONFIRM CONFIG =================

class _ConfirmCfg {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const _ConfirmCfg(this.title, this.message, this.color, this.icon);
}

_ConfirmCfg _confirmConfig(String type) {
  switch (type) {
    case 'shutdown':
      return const _ConfirmCfg(
        'SHUTDOWN PC',
        'This will immediately power off the computer.\nUnsaved work will be lost.',
        Colors.redAccent,
        Icons.power_settings_new,
      );
    case 'restart':
      return const _ConfirmCfg(
        'RESTART PC',
        'The computer will reboot.\nActive users will be disconnected.',
        Colors.cyanAccent,
        Icons.restart_alt,
      );
    case 'lock':
      return const _ConfirmCfg(
        'LOCK PC',
        'The screen will be locked and user input disabled.',
        Colors.orangeAccent,
        Icons.lock,
      );
    case 'end_session':
      return const _ConfirmCfg(
        'END SESSION',
        'Session time will stop and billing will finalize.',
        Colors.deepOrangeAccent,
        Icons.stop_circle,
      );
    default:
      return const _ConfirmCfg(
        'CONFIRM ACTION',
        'Are you sure you want to proceed?',
        Colors.white,
        Icons.warning,
      );
  }
}
