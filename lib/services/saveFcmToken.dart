import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> saveFcmToken() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final token = await messaging.getToken();
  if (token == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'fcmToken': token,
    'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  messaging.onTokenRefresh.listen((newToken) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'fcmToken': newToken,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}