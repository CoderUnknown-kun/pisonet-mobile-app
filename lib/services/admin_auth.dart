import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuth {
  // Flag you can read from UI / logs if needed
  static bool isReady = false;

  /// Ensure anonymous auth + admin document exists.
  /// This function is idempotent and safe to call multiple times.
  static Future<void> ensureAdminLoggedIn() async {
  if (isReady) return;

  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;

  try {
    // 🔐 Sign in anonymously if not logged in
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }

    final uid = auth.currentUser!.uid;
    print("🔥 Flutter UID: $uid");

    final adminRef = db.collection('admins').doc(uid);
    final snap = await adminRef.get();

    // 🧠 Ensure admin record exists (create if missing)
    if (!snap.exists) {
      await adminRef.set({
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    isReady = true;

  } catch (e) {
    isReady = false;
    rethrow;
  }
}
}
