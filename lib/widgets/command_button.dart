import 'package:flutter/material.dart';

class CommandButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const CommandButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(disabled ? 0.08 : 0.25),
                color.withOpacity(disabled ? 0.03 : 0.05),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(disabled ? 0.3 : 0.8),
              width: 1.2,
            ),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 0.5,
                    ),
                  ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: Colors.white.withOpacity(disabled ? 0.5 : 1),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(disabled ? 0.5 : 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
