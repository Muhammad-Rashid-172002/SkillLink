import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationManagementService {
  NotificationManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream() {
    return _notifications.snapshots();
  }

  Future<void> createNotification({
    required String title,
    required String message,
    required String audience,
    required String type,
    String? targetUserId,
    String? targetUserName,
  }) async {
    await _notifications.add({
      'title': title.trim(),
      'message': message.trim(),
      'audience': audience,
      'type': type,
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
      'isRead': false,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
      'sentBy': 'admin',
    });
  }

  Future<void> markAsRead({
    required String notificationId,
    required bool isRead,
  }) async {
    await _notifications.doc(notificationId).update({
      'isRead': isRead,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveNotification(String notificationId) async {
    await _notifications.doc(notificationId).update({
      'status': 'archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restoreNotification(String notificationId) async {
    await _notifications.doc(notificationId).update({
      'status': 'sent',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNotification(String notificationId) async {
    await _notifications.doc(notificationId).delete();
  }
}

class ManagedNotification {
  const ManagedNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.audience,
    required this.type,
    required this.status,
    required this.targetUserName,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String audience;
  final String type;
  final String status;
  final String targetUserName;
  final bool isRead;
  final DateTime? createdAt;

  bool get isArchived => status == 'archived';

  factory ManagedNotification.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return ManagedNotification(
      id: document.id,
      title: _firstString(
        data,
        const ['title', 'subject'],
        fallback: 'Notification',
      ),
      message: _firstString(
        data,
        const ['message', 'body', 'description'],
        fallback: 'No message',
      ),
      audience: _firstString(
        data,
        const ['audience', 'receiverType'],
        fallback: 'all',
      ).toLowerCase(),
      type: _firstString(
        data,
        const ['type', 'category'],
        fallback: 'general',
      ).toLowerCase(),
      status: _firstString(
        data,
        const ['status'],
        fallback: 'sent',
      ).toLowerCase(),
      targetUserName: _firstString(
        data,
        const ['targetUserName', 'receiverName', 'userName'],
        fallback: 'All Users',
      ),
      isRead: _firstBool(
        data,
        const ['isRead', 'read'],
      ),
      createdAt: _firstDate(
        data,
        const ['createdAt', 'sentAt', 'date'],
      ),
    );
  }

  static String _firstString(
    Map<String, dynamic> data,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static bool _firstBool(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
    }
    return false;
  }

  static DateTime? _firstDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
    }
    return null;
  }
}
