import 'package:flutter/material.dart';

enum CommandStatus {
  sent,
  success,
  error,
}

class CommandBanner extends StatelessWidget {
  final String command;
  final CommandStatus status;

  const CommandBanner({
    super.key,
    required this.command,
    required this.status,
  });

  Color get _statusColor {
    switch (status) {
      case CommandStatus.success:
        return Colors.greenAccent;
      case CommandStatus.error:
        return Colors.redAccent;
      case CommandStatus.sent:
        return Colors.blueAccent;
    }
  }

  String get _label {
    switch (status) {
      case CommandStatus.success:
        return 'Command executed';
      case CommandStatus.error:
        return 'Command failed';
      case CommandStatus.sent:
        return 'Command sent';
    }
  }

  IconData get _icon {
    switch (command) {
      case 'lock':
        return Icons.lock_outline;
      case 'restart':
        return Icons.restart_alt;
      case 'shutdown':
        return Icons.power_settings_new;
      default:
        return Icons.send_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _statusColor.withAlpha(90), // ~35%
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(40), // ~15%
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                color: _statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    command.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _label,
                    style: TextStyle(
                      color: Colors.white.withAlpha(180),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
