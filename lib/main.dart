import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart'; // ✅ ADD

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/admin_auth.dart';

// 🌗 GLOBAL THEME CONTROLLER
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INIT FIREBASE
  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔥 CRITICAL FIX: BIND TO CORRECT RTDB REGION
  FirebaseDatabase.instanceFor(
    app: app,
    databaseURL:
        'https://mlsn-industries-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // 🔐 ADMIN AUTH — MUST COMPLETE BEFORE UI
  try {
    await AdminAuth.ensureAdminLoggedIn();
    debugPrint('✅ Admin auth completed');
  } catch (e) {
    debugPrint('❌ Admin auth failed: $e');
  }

  // 🚀 START UI ONLY AFTER AUTH IS READY
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Pisonet Monitor',
          debugShowCheckedModeBanner: false,
          themeMode: mode,

          // ☀️ LIGHT THEME
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: Colors.blue,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              centerTitle: true,
            ),
          ),

          // 🌙 DARK THEME
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.blue,
            scaffoldBackgroundColor: const Color(0xFF020617),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF020617),
              foregroundColor: Colors.white70,
              elevation: 0,
              centerTitle: true,
            ),
          ),

          home: const HomeScreen(),
        );
      },
    );
  }
}
