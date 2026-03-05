import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class AddPCScreen extends StatefulWidget {
  const AddPCScreen({super.key});

  @override
  State<AddPCScreen> createState() => _AddPCScreenState();
}

class _AddPCScreenState extends State<AddPCScreen> {
  final _id = TextEditingController();
  final _name = TextEditingController();
  final _ip = TextEditingController();
  final _note = TextEditingController();

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    if (_id.text.trim().isEmpty || _ip.text.trim().isEmpty) return;

    setState(() => _saving = true);

    final id = _id.text.trim();
    final name =
        _name.text.trim().isEmpty ? id : _name.text.trim();
    final ip = _ip.text.trim();
    final note =
        _note.text.trim().isEmpty ? null : _note.text.trim();

    // 🚀 OPTIMISTIC UI: close immediately
    if (mounted) Navigator.pop(context);

    // 🔥 Fire-and-forget write (non-blocking)
    try {
      await FirebaseService.instance.addPC(
        id: id,
        name: name,
        ip: ip,
        note: note,
      );
    } catch (e) {
      // Silent fail for now (can add snackbar later if you want)
      debugPrint('Add PC failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        elevation: 0,
        title: const Text(
          'Add PC',
          style: TextStyle(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _glassPanel(
          child: Column(
            children: [
              _field(
                controller: _id,
                label: 'PC ID',
                icon: Icons.computer,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _name,
                label: 'Name (optional)',
                icon: Icons.badge,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _ip,
                label: 'IP Address',
                icon: Icons.wifi,
              ),
              const SizedBox(height: 14),
              _field(
                controller: _note,
                label: 'Note (optional)',
                icon: Icons.notes,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'SAVE PC',
                          style: TextStyle(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================
  // UI HELPERS (VISUAL ONLY)
  // ===============================

  Widget _glassPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B0F1A),
            Color(0xFF111827),
          ],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
