import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> send({
    required String userId,
    required String role,
    required String type,
    required String title,
    required String message,
    String? requestId,
    String? chatId,
  }) async {
    await _firestore.collection("notifications").add({
      "userId": userId,
      "role": role,
      "type": type,
      "title": title,
      "message": message,
      "requestId": requestId,
      "chatId": chatId,
      "isRead": false,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  static Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection("notifications")
        .doc(notificationId)
        .update({
      "isRead": true,
    });
  }

  static Future<void> delete(String notificationId) async {
    await _firestore
        .collection("notifications")
        .doc(notificationId)
        .delete();
  }

  static Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection("notifications")
        .where("userId", isEqualTo: userId)
        .where("isRead", isEqualTo: false)
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        "isRead": true,
      });
    }

    await batch.commit();
  }
}