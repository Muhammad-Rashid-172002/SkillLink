import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skilllink_admin/screens/admin_login_screen.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SkillLinkAdminApp());
}

class SkillLinkAdminApp extends StatelessWidget {
  const SkillLinkAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillLink Admin',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
        ),
      ),
      home: const AdminLoginScreen(),
    );
  }
}


// Meri Recommendation

// Dashboard ko ek hi file mein mat banana.

// Professional structure rakho:

// dashboard_screen.dart
// sidebar.dart
// topbar.dart
// dashboard_service.dart
// stat_card.dart
// dashboard_model.dart

// Is tarah future mein code maintain karna bohot aasaan hoga.

// Main suggest karta hoon agla step ye ho:
// Professional Sidebar (responsive)
// Top Navigation Bar
// Dashboard Layout
// Live Firebase Statistics

// Uske baad hum Users, Jobs aur baaki modules add karenge.