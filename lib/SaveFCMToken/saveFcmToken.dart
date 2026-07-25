import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> saveFcmToken() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  final String? token =
      await FirebaseMessaging.instance.getToken();

  if (token == null || token.isEmpty) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
    'fcmToken': token,
    'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}