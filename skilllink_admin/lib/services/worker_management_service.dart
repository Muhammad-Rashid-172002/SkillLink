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
    // The mobile app gates job acceptance on identityVerificationStatus /
    // canAcceptJobs (same fields the Verifications page writes); the legacy
    // isVerified/verificationStatus flags are kept for older readers.
    await _users.doc(workerId).update({
      'identityVerificationStatus': isVerified ? 'approved' : 'pending',
      'verificationLevel': isVerified ? 'identity_verified' : 'unverified',
      'canAcceptJobs': isVerified,
      'isVerified': isVerified,
      'verificationStatus': isVerified ? 'verified' : 'pending',
      'verifiedAt': isVerified
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setVerificationStatus({
    required String workerId,
    required String status,
    String? reason,
  }) async {
    final approved = status == 'verified';
    await _users.doc(workerId).update({
      'identityVerificationStatus': switch (status) {
        'verified' => 'approved',
        'rejected' => 'rejected',
        _ => 'pending',
      },
      'verificationLevel': approved ? 'identity_verified' : 'unverified',
      'canAcceptJobs': approved,
      'verificationStatus': status,
      'isVerified': approved,
      'verificationReason': reason?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'verified') 'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setWorkerBlocked({
    required String workerId,
    required bool isBlocked,
  }) async {
    // The app restricts sign-in by accountStatus; isBlocked is legacy.
    await _users.doc(workerId).update({
      'accountStatus': isBlocked ? 'blocked' : 'active',
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
      name: _firstString(data, const [
        'name',
        'fullName',
        'displayName',
        'userName',
      ], fallback: 'Unnamed Worker'),
      email: _firstString(data, const ['email'], fallback: 'No email'),
      phone: _firstString(data, const [
        'phone',
        'phoneNumber',
        'mobile',
      ], fallback: 'Not provided'),
      skill: _firstString(data, const [
        'skill',
        'category',
        'profession',
        'serviceName',
      ], fallback: 'General Worker'),
      experience: _firstString(data, const [
        'experience',
        'experienceYears',
        'workExperience',
      ], fallback: 'Not provided'),
      rating: _firstDouble(data, const [
        'rating',
        'averageRating',
        'avgRating',
      ]),
      completedJobs: _firstInt(data, const [
        'completedJobs',
        'completedJobCount',
        'jobsCompleted',
      ]),
      isVerified: _verification(data) == 'verified',
      // Blocked as the mobile app enforces it (accountStatus), plus legacy
      // flags written by older console versions.
      isBlocked:
          const {
            'blocked',
            'suspended',
          }.contains(data['accountStatus']?.toString().trim().toLowerCase()) ||
          _firstBool(data, const ['isBlocked', 'blocked', 'isDisabled']),
      verificationStatus: _verification(data),
      cnic: _firstString(data, const [
        'cnic',
        'cnicNumber',
        'nationalId',
      ], fallback: 'Not provided'),
      cnicFrontUrl: _nullableString(data, const [
        'cnicFrontUrl',
        'cnicFront',
        'idFrontUrl',
      ]),
      cnicBackUrl: _nullableString(data, const [
        'cnicBackUrl',
        'cnicBack',
        'idBackUrl',
      ]),
      photoUrl: _nullableString(data, const [
        'photoUrl',
        'profileImage',
        'imageUrl',
      ]),
      createdAt: _firstDate(data, const [
        'createdAt',
        'joinedAt',
        'registeredAt',
      ]),
      rawData: data,
    );
  }

  /// Verification as the mobile app sees it (identityVerificationStatus),
  /// in this console's vocabulary, with legacy flags as a fallback.
  static String _verification(Map<String, dynamic> data) {
    switch (data['identityVerificationStatus']
        ?.toString()
        .trim()
        .toLowerCase()) {
      case 'approved':
        return 'verified';
      case 'rejected':
        return 'rejected';
      case 'pending':
        return 'pending';
      case 'not_submitted':
        return 'not submitted';
    }
    final legacy = data['verificationStatus']?.toString().trim().toLowerCase();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return _firstBool(data, const ['isVerified', 'verified', 'workerVerified'])
        ? 'verified'
        : 'pending';
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

  static String? _nullableString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static bool _firstBool(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is bool) return value;
    }
    return false;
  }

  static int _firstInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return 0;
  }

  static double _firstDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
    }
    return 0;
  }

  static DateTime? _firstDate(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
    }

    return null;
  }
}
