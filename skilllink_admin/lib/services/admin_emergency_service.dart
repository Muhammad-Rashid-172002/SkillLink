import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminEmergencyServiceException implements Exception {
  const AdminEmergencyServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AdminEmergencyService {
  AdminEmergencyService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<QuerySnapshot<Map<String, dynamic>>> alertsStream() {
    return _firestore
        .collection('emergency_alerts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<int> activeAlertCountStream() {
    return _firestore
        .collection('emergency_alerts')
        .where('status', whereIn: const ['active', 'investigating'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<Map<String, Map<String, dynamic>>> loadRelatedUsers({
    required String customerId,
    required String workerId,
  }) async {
    final result = <String, Map<String, dynamic>>{};

    final futures = <Future<void>>[];

    if (customerId.trim().isNotEmpty) {
      futures.add(
        _firestore.collection('users').doc(customerId).get().then((doc) {
          if (doc.exists && doc.data() != null) {
            result['customer'] = doc.data()!;
          }
        }),
      );
    }

    if (workerId.trim().isNotEmpty) {
      futures.add(
        _firestore.collection('users').doc(workerId).get().then((doc) {
          if (doc.exists && doc.data() != null) {
            result['worker'] = doc.data()!;
          }
        }),
      );
    }

    await Future.wait(futures);
    return result;
  }

  Future<void> markInvestigating({
    required String alertId,
    String? note,
  }) async {
    final adminId = _auth.currentUser?.uid;

    if (adminId == null) {
      throw const AdminEmergencyServiceException(
        'Admin session expired. Please sign in again.',
      );
    }

    await _firestore.collection('emergency_alerts').doc(alertId).update({
      'status': 'investigating',
      'investigatingBy': adminId,
      'investigatingAt': FieldValue.serverTimestamp(),
      'investigationNote': note?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolveAlert({
    required String alertId,
    required String requestId,
    required String resolution,
    bool falseAlarm = false,
  }) async {
    final adminId = _auth.currentUser?.uid;

    if (adminId == null) {
      throw const AdminEmergencyServiceException(
        'Admin session expired. Please sign in again.',
      );
    }

    final alertRef = _firestore.collection('emergency_alerts').doc(alertId);
    final requestRef = _firestore.collection('requests').doc(requestId);
    final batch = _firestore.batch();

    batch.update(alertRef, {
      'status': falseAlarm ? 'false_alarm' : 'resolved',
      'resolution': resolution.trim(),
      'resolvedBy': adminId,
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (requestId.trim().isNotEmpty) {
      batch.set(
        requestRef,
        {
          'hasActiveEmergency': false,
          'activeEmergencyAlertId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> deleteResolvedAlert(String alertId) async {
    final doc = await _firestore.collection('emergency_alerts').doc(alertId).get();
    final status = doc.data()?['status']?.toString().toLowerCase() ?? '';

    if (status != 'resolved' && status != 'false_alarm') {
      throw const AdminEmergencyServiceException(
        'Only resolved or false-alarm alerts can be deleted.',
      );
    }

    await doc.reference.delete();
  }
}
