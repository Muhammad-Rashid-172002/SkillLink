import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerManagementService {
  WorkerManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<QuerySnapshot<Map<String, dynamic>>> workersStream() {
    return _users.where('role', isEqualTo: 'worker').snapshots();
  }

  Future<void> setWorkerVerified({
    required String workerId,
    required bool isVerified,
  }) async {
    await _users.doc(workerId).update({
      'isVerified': isVerified,
      'verificationStatus': isVerified ? 'verified' : 'pending',
      'verifiedAt':
          isVerified ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setVerificationStatus({
    required String workerId,
    required String status,
    String? reason,
  }) async {
    await _users.doc(workerId).update({
      'verificationStatus': status,
      'isVerified': status == 'verified',
      'verificationReason': reason?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'verified') 'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setWorkerBlocked({
    required String workerId,
    required bool isBlocked,
  }) async {
    await _users.doc(workerId).update({
      'isBlocked': isBlocked,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class ManagedWorker {
  const ManagedWorker({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.skill,
    required this.experience,
    required this.rating,
    required this.completedJobs,
    required this.isVerified,
    required this.isBlocked,
    required this.verificationStatus,
    required this.cnic,
    required this.cnicFrontUrl,
    required this.cnicBackUrl,
    required this.photoUrl,
    required this.createdAt,
    required this.rawData,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String skill;
  final String experience;
  final double rating;
  final int completedJobs;
  final bool isVerified;
  final bool isBlocked;
  final String verificationStatus;
  final String cnic;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? photoUrl;
  final DateTime? createdAt;
  final Map<String, dynamic> rawData;

  factory ManagedWorker.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return ManagedWorker(
      id: document.id,
      name: _firstString(
        data,
        const ['name', 'fullName', 'displayName', 'userName'],
        fallback: 'Unnamed Worker',
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
      skill: _firstString(
        data,
        const ['skill', 'category', 'profession', 'serviceName'],
        fallback: 'General Worker',
      ),
      experience: _firstString(
        data,
        const ['experience', 'experienceYears', 'workExperience'],
        fallback: 'Not provided',
      ),
      rating: _firstDouble(
        data,
        const ['rating', 'averageRating', 'avgRating'],
      ),
      completedJobs: _firstInt(
        data,
        const ['completedJobs', 'completedJobCount', 'jobsCompleted'],
      ),
      isVerified: _firstBool(
        data,
        const ['isVerified', 'verified', 'workerVerified'],
      ),
      isBlocked: _firstBool(
        data,
        const ['isBlocked', 'blocked', 'isDisabled'],
      ),
      verificationStatus: _firstString(
        data,
        const ['verificationStatus'],
        fallback: _firstBool(
          data,
          const ['isVerified', 'verified', 'workerVerified'],
        )
            ? 'verified'
            : 'pending',
      ).toLowerCase(),
      cnic: _firstString(
        data,
        const ['cnic', 'cnicNumber', 'nationalId'],
        fallback: 'Not provided',
      ),
      cnicFrontUrl: _nullableString(
        data,
        const ['cnicFrontUrl', 'cnicFront', 'idFrontUrl'],
      ),
      cnicBackUrl: _nullableString(
        data,
        const ['cnicBackUrl', 'cnicBack', 'idBackUrl'],
      ),
      photoUrl: _nullableString(
        data,
        const ['photoUrl', 'profileImage', 'imageUrl'],
      ),
      createdAt: _firstDate(
        data,
        const ['createdAt', 'joinedAt', 'registeredAt'],
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
      if (value is num) {
        return value.toString();
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
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
    }
    return false;
  }

  static int _firstInt(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return 0;
  }

  static double _firstDouble(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
    }
    return 0;
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
