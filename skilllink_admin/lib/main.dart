import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:skilllink_admin/theme/admin_design.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:skilllink_admin/screens/admin_login_screen.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // QA only: `--dart-define=USE_FIREBASE_EMULATOR=true` points the console at
  // the local Firebase Emulator Suite. Never enabled in release builds.
  const useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
  if (useEmulator && !kReleaseMode) {
    const host = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: 'localhost',
    );
    await FirebaseAuth.instance.useAuthEmulator(
      host,
      const int.fromEnvironment(
        'FIREBASE_AUTH_EMULATOR_PORT',
        defaultValue: 9099,
      ),
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      const int.fromEnvironment(
        'FIREBASE_FIRESTORE_EMULATOR_PORT',
        defaultValue: 8080,
      ),
    );
    // Verification photos live in Storage; without this the console tried
    // to load them from production while in emulator mode.
    await FirebaseStorage.instance.useStorageEmulator(
      host,
      const int.fromEnvironment(
        'FIREBASE_STORAGE_EMULATOR_PORT',
        defaultValue: 9199,
      ),
    );
    // Account deletion and suspension run as callable Cloud Functions.
    FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(
      host,
      const int.fromEnvironment(
        'FIREBASE_FUNCTIONS_EMULATOR_PORT',
        defaultValue: 5001,
      ),
    );
  }

  runApp(const SkillLinkAdminApp());
}

class SkillLinkAdminApp extends StatelessWidget {
  const SkillLinkAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SkillNova Admin',
      theme: AdminTheme.light,
      home: const AdminLoginScreen(),
    );
  }
}
