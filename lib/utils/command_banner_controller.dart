import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/command_banner.dart';

class CommandBannerController {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String command,
    CommandStatus status = CommandStatus.sent,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 0,
        right: 0,
        child: _AnimatedBanner(
          child: CommandBanner(
            command: command,
            status: status,
          ),
        ),
      ),
    );

    overlay.insert(entry);
    _currentEntry = entry;

    Timer(duration, () {
      entry.remove();
      _currentEntry = null;
    });
  }
}

class _AnimatedBanner extends StatefulWidget {
  final Widget child;

  const _AnimatedBanner({required this.child});

  @override
  State<_AnimatedBanner> createState() => _AnimatedBannerState();
}

class _AnimatedBannerState extends State<_AnimatedBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: widget.child,
    );
  }
}
