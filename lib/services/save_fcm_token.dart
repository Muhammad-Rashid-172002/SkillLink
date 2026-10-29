import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Stores this device's push token on the signed-in user's profile.
///
/// IMPORTANT: this uses `update()`, never `set(merge: true)`. A merge-set
/// creates `users/{uid}` when it does not exist yet; during sign-up the auth
/// listener fires *before* the profile is written, which used to create a
/// profile containing only `fcmToken` and no `role`. That half-created
/// document is what later produced "Account role is invalid" on login.
Future<void> syncFcmToken(String uid, String token) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  } on FirebaseException catch (error) {
    // not-found: profile not created yet; the token is saved again after
    // sign-up completes (saveFcmToken) or on the next token refresh.
    debugPrint('FCM token not stored (${error.code}).');
  }
}

StreamSubscription<String>? _tokenRefreshSubscription;

Future<void> saveFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await syncFcmToken(user.uid, token);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
      final current = FirebaseAuth.instance.currentUser;
      if (current != null) syncFcmToken(current.uid, newToken);
    });
  } catch (error) {
    // Push registration must never block sign-in.
    debugPrint('FCM registration skipped: $error');
  }
}
