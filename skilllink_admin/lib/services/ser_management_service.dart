import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementService {
  UserManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _users.snapshots();
  }

  Future<void> setUserBlocked({
    required String userId,
    required bool isBlocked,
  }) async {
    await _users.doc(userId).update({
      'isBlocked': isBlocked,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setWorkerVerified({
    required String userId,
    required bool isVerified,
  }) async {
    await _users.doc(userId).update({
      'isVerified': isVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUserDocument(String userId) async {
    await _users.doc(userId).delete();
  }
}

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isBlocked,
    required this.isVerified,
    required this.createdAt,
    required this.photoUrl,
    required this.rawData,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isBlocked;
  final bool isVerified;
  final DateTime? createdAt;
  final String? photoUrl;
  final Map<String, dynamic> rawData;

  bool get isWorker => role.toLowerCase() == 'worker';
  bool get isCustomer => role.toLowerCase() == 'customer';

  factory ManagedUser.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return ManagedUser(
      id: document.id,
      name: _firstString(
        data,
        const ['name', 'fullName', 'displayName', 'userName'],
        fallback: 'Unnamed User',
      ),
      email: _firstString(
        data,
        const ['email'],
        fallback: 'No email',
      ),
      phone: _firstString(
        data,
        const ['phone', 'phoneNumber', 'mobile'],
        fallback: 'Not provided',
      ),
      role: _firstString(
        data,
        const ['role', 'userType', 'type'],
        fallback: 'user',
      ).toLowerCase(),
      isBlocked: _firstBool(
        data,
        const ['isBlocked', 'blocked', 'isDisabled'],
        fallback: false,
      ),
      isVerified: _firstBool(
        data,
        const ['isVerified', 'verified', 'workerVerified'],
        fallback: false,
      ),
      createdAt: _firstDate(
        data,
        const ['createdAt', 'joinedAt', 'registeredAt'],
      ),
      photoUrl: _nullableString(
        data,
        const ['photoUrl', 'profileImage', 'imageUrl'],
      ),
      rawData: data,
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

  static String? _nullableString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static bool _firstBool(
    Map<String, dynamic> data,
    List<String> keys, {
    required bool fallback,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
    }
    return fallback;
  }

  static DateTime? _firstDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        return DateTime.tryParse(value);
      }
    }

    return null;
  }
}
