
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VerificationRequestModel {
  const VerificationRequestModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.workerEmail,
    required this.workerPhone,
    required this.skill,
    required this.status,
    required this.cnicFrontPath,
    required this.cnicBackPath,
    required this.liveSelfiePath,
    required this.submittedAt,
  });

  final String id;
  final String workerId;
  final String workerName;
  final String workerEmail;
  final String workerPhone;
  final String skill;
  final String status;
  final String cnicFrontPath;
  final String cnicBackPath;
  final String liveSelfiePath;
  final DateTime? submittedAt;

  bool get isPending => const {
        'pending',
        'submitted',
        'in_review',
      }.contains(status);

  factory VerificationRequestModel.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    String text(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return fallback;
    }

    DateTime? date(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
      }
      return null;
    }

    return VerificationRequestModel(
      id: document.id,
      workerId: text(['workerId'], fallback: document.id),
      workerName: text(['workerName', 'name', 'fullName'], fallback: 'Worker'),
      workerEmail: text(['workerEmail', 'email'], fallback: 'No email'),
      workerPhone: text(['workerPhone', 'phone', 'phoneNumber'], fallback: 'No phone'),
      skill: text(['skill', 'service', 'category'], fallback: 'Worker'),
      status: text(['identityStatus', 'status'], fallback: 'pending').toLowerCase(),
      cnicFrontPath: text(['cnicFrontPath']),
      cnicBackPath: text(['cnicBackPath']),
      liveSelfiePath: text(['liveSelfiePath', 'selfiePath']),
      submittedAt: date(['submittedAt', 'createdAt']),
    );
  }
}

class VerificationManagementService {
  VerificationManagementService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  Stream<QuerySnapshot<Map<String, dynamic>>> requestsStream() {
    return _firestore.collection('verification_requests').snapshots();
  }

 Future<String?> getPrivateImageUrl(String storagePath) async {
  final cleanPath = storagePath.trim();

  if (cleanPath.isEmpty) {
    return null;
  }

  return _storage.ref(cleanPath).getDownloadURL();
}

  Future<void> approve(VerificationRequestModel request, {String note = ''}) async {
    final admin = _auth.currentUser;
    if (admin == null) throw StateError('Admin session not found.');

    final batch = _firestore.batch();
    final requestRef = _firestore.collection('verification_requests').doc(request.id);
    final userRef = _firestore.collection('users').doc(request.workerId);
    final auditRef = _firestore.collection('admin_audit_logs').doc();

    batch.set(requestRef, {
      'identityStatus': 'approved',
      'status': 'approved',
      'reviewNote': note.trim(),
      'reviewedBy': admin.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'identityVerificationStatus': 'approved',
      'verificationLevel': 'identity_verified',
      'canAcceptJobs': true,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(auditRef, {
      'action': 'worker_identity_approved',
      'targetUserId': request.workerId,
      'targetRequestId': request.id,
      'adminId': admin.uid,
      'adminEmail': admin.email,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> reject(VerificationRequestModel request, String reason) async {
    final admin = _auth.currentUser;
    if (admin == null) throw StateError('Admin session not found.');
    if (reason.trim().isEmpty) throw ArgumentError('Rejection reason required.');

    final batch = _firestore.batch();
    final requestRef = _firestore.collection('verification_requests').doc(request.id);
    final userRef = _firestore.collection('users').doc(request.workerId);

    batch.set(requestRef, {
      'identityStatus': 'rejected',
      'status': 'rejected',
      'rejectionReason': reason.trim(),
      'reviewedBy': admin.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'identityVerificationStatus': 'rejected',
      'verificationLevel': 'unverified',
      'canAcceptJobs': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> requestResubmission(
    VerificationRequestModel request,
    String reason,
  ) async {
    final admin = _auth.currentUser;
    if (admin == null) throw StateError('Admin session not found.');
    if (reason.trim().isEmpty) throw ArgumentError('Reason required.');

    final batch = _firestore.batch();
    final requestRef = _firestore.collection('verification_requests').doc(request.id);
    final userRef = _firestore.collection('users').doc(request.workerId);

    batch.set(requestRef, {
      'identityStatus': 'more_information_required',
      'status': 'more_information_required',
      'resubmissionReason': reason.trim(),
      'reviewedBy': admin.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'identityVerificationStatus': 'more_information_required',
      'canAcceptJobs': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
