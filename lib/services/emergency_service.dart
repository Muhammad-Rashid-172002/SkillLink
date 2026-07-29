import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyServiceException implements Exception {
  final String message;

  const EmergencyServiceException(this.message);

  @override
  String toString() => message;
}

class EmergencyService {
  EmergencyService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String> createEmergencyAlert({
    required String requestId,
    required Map<String, dynamic> requestData,
    required String workerId,
    required String raisedByRole,
    required String jobStatus,
    required String reason,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const EmergencyServiceException(
        'Please log in again before sending an SOS alert.',
      );
    }

    if (!_isActiveJobStatus(jobStatus)) {
      throw const EmergencyServiceException(
        'SOS is available only during an active job.',
      );
    }

    final position = await _getCurrentPosition();

    final requestRef = _firestore.collection('requests').doc(requestId);
    final alertRef = _firestore.collection('emergency_alerts').doc();
    final adminNotificationRef =
        _firestore.collection('admin_notifications').doc();

    await _firestore.runTransaction((transaction) async {
      final freshRequest = await transaction.get(requestRef);

      if (!freshRequest.exists || freshRequest.data() == null) {
        throw const EmergencyServiceException(
          'This service request no longer exists.',
        );
      }

      final freshData = freshRequest.data()!;
      final currentStatus =
          freshData['status']?.toString().trim().toLowerCase() ?? '';

      if (!_isActiveJobStatus(currentStatus)) {
        throw const EmergencyServiceException(
          'This job is no longer active.',
        );
      }

      final existingAlertId =
          freshData['activeEmergencyAlertId']?.toString().trim() ?? '';

      if (existingAlertId.isNotEmpty) {
        final existingAlertRef =
            _firestore.collection('emergency_alerts').doc(existingAlertId);
        final existingAlert = await transaction.get(existingAlertRef);
        final existingStatus =
            existingAlert.data()?['status']?.toString().toLowerCase() ?? '';

        if (existingAlert.exists &&
            (existingStatus == 'active' ||
                existingStatus == 'investigating')) {
          throw const EmergencyServiceException(
            'An active SOS alert already exists for this job.',
          );
        }
      }

      final customerId =
          freshData['customerId']?.toString().trim() ??
              requestData['customerId']?.toString().trim() ??
              '';

      final resolvedWorkerId =
          freshData['workerId']?.toString().trim().isNotEmpty == true
              ? freshData['workerId'].toString().trim()
              : workerId;

      final raisedByName = _firstNonEmpty([
        freshData['customerName'],
        requestData['customerName'],
        user.displayName,
        user.email,
        'Customer',
      ]);

      final serviceTitle = _firstNonEmpty([
        freshData['title'],
        requestData['title'],
        freshData['category'],
        requestData['category'],
        'Service request',
      ]);

      final jobAddress = _firstNonEmpty([
        freshData['location'],
        freshData['address'],
        requestData['location'],
        requestData['address'],
        'Location unavailable',
      ]);

      final alertData = <String, dynamic>{
        'alertId': alertRef.id,
        'requestId': requestId,
        'jobId': requestId,
        'raisedBy': user.uid,
        'raisedByRole': raisedByRole,
        'raisedByName': raisedByName,
        'raisedByEmail': user.email,
        'customerId': customerId,
        'workerId': resolvedWorkerId,
        'jobStatus': currentStatus,
        'serviceTitle': serviceTitle,
        'serviceCategory': freshData['category'] ?? requestData['category'],
        'jobAddress': jobAddress,
        'reason': reason.trim().isEmpty
            ? 'Emergency assistance required'
            : reason.trim(),
        'status': 'active',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'locationTimestamp': Timestamp.fromDate(position.timestamp),
        'mapsUrl':
            'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'resolvedBy': null,
      };

      transaction.set(alertRef, alertData);

      transaction.update(requestRef, {
        'hasActiveEmergency': true,
        'activeEmergencyAlertId': alertRef.id,
        'lastEmergencyAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(adminNotificationRef, {
        'title': 'Emergency SOS Alert',
        'message':
            '$raisedByName sent an SOS during "$serviceTitle". Immediate review required.',
        'type': 'emergency_alert',
        'alertId': alertRef.id,
        'requestId': requestId,
        'raisedBy': user.uid,
        'raisedByRole': raisedByRole,
        'isRead': false,
        'priority': 'critical',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    return alertRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activeAlertsStream() {
    return _firestore
        .collection('emergency_alerts')
        .where('status', whereIn: ['active', 'investigating'])
        .snapshots();
  }

  Future<void> markInvestigating({
    required String alertId,
    required String adminId,
  }) async {
    await _firestore.collection('emergency_alerts').doc(alertId).update({
      'status': 'investigating',
      'investigatingBy': adminId,
      'investigatingAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolveAlert({
    required String alertId,
    required String requestId,
    required String adminId,
    required String resolution,
    bool falseAlarm = false,
  }) async {
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

    batch.update(requestRef, {
      'hasActiveEmergency': false,
      'activeEmergencyAlertId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<Position> _getCurrentPosition() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();

    if (!servicesEnabled) {
      throw const EmergencyServiceException(
        'Please turn on Location Services before sending SOS.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const EmergencyServiceException(
        'Location permission is required to send your SOS location.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const EmergencyServiceException(
        'Location permission is permanently denied. Enable it from device settings.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      final lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null) return lastKnown;

      throw const EmergencyServiceException(
        'Current location could not be detected. Please call Police 15.',
      );
    }
  }

  static bool _isActiveJobStatus(String status) {
    final normalized = status.trim().toLowerCase().replaceAll(' ', '_');

    return normalized == 'accepted' ||
        normalized == 'on_the_way' ||
        normalized == 'in_progress';
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
