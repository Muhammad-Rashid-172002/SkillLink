import 'package:cloud_firestore/cloud_firestore.dart';

class JobManagementService {
  JobManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('requests');

  Stream<QuerySnapshot<Map<String, dynamic>>> jobsStream() {
    return _requests.snapshots();
  }

  Future<void> updateJobStatus({
    required String jobId,
    required String status,
  }) async {
    await _requests.doc(jobId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelJob({
    required String jobId,
    required String reason,
  }) async {
    await _requests.doc(jobId).update({
      'status': 'cancelled',
      'cancelReason': reason.trim(),
      'cancelledBy': 'admin',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteJob(String jobId) async {
    await _requests.doc(jobId).delete();
  }
}

class ManagedJob {
  const ManagedJob({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.workerName,
    required this.workerEmail,
    required this.address,
    required this.budget,
    required this.createdAt,
    required this.updatedAt,
    required this.rawData,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String status;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String workerName;
  final String workerEmail;
  final String address;
  final double budget;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> rawData;

  bool get isPending => const {
        'pending',
        'waiting_worker',
        'searching',
        'requested',
      }.contains(status);

  bool get isActive => const {
        'accepted',
        'on_the_way',
        'in_progress',
        'started',
      }.contains(status);

  bool get isCompleted => status == 'completed';

  bool get isCancelled => const {
        'cancelled',
        'rejected',
      }.contains(status);

  factory ManagedJob.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return ManagedJob(
      id: document.id,
      title: _firstString(
        data,
        const ['serviceName', 'title', 'jobTitle', 'category'],
        fallback: 'Service Job',
      ),
      category: _firstString(
        data,
        const ['category', 'serviceName', 'serviceCategory'],
        fallback: 'General Service',
      ),
      description: _firstString(
        data,
        const ['description', 'details', 'jobDescription', 'issue'],
        fallback: 'No description provided',
      ),
      status: _firstString(
        data,
        const ['status'],
        fallback: 'pending',
      ).toLowerCase(),
      customerName: _firstString(
        data,
        const ['customerName', 'userName', 'clientName', 'name'],
        fallback: 'Customer',
      ),
      customerEmail: _firstString(
        data,
        const ['customerEmail', 'userEmail', 'clientEmail'],
        fallback: 'No email',
      ),
      customerPhone: _firstString(
        data,
        const ['customerPhone', 'phone', 'phoneNumber', 'mobile'],
        fallback: 'Not provided',
      ),
      workerName: _firstString(
        data,
        const ['workerName', 'providerName'],
        fallback: 'Not assigned',
      ),
      workerEmail: _firstString(
        data,
        const ['workerEmail', 'providerEmail'],
        fallback: 'No email',
      ),
      address: _firstString(
        data,
        const ['address', 'locationAddress', 'location', 'jobAddress'],
        fallback: 'Location not provided',
      ),
      budget: _firstDouble(
        data,
        const ['budget', 'price', 'amount', 'estimatedPrice'],
      ),
      createdAt: _firstDate(
        data,
        const ['createdAt', 'requestedAt', 'date'],
      ),
      updatedAt: _firstDate(
        data,
        const ['updatedAt', 'acceptedAt', 'completedAt'],
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

      if (value is GeoPoint) {
        return '${value.latitude}, ${value.longitude}';
      }
    }

    return fallback;
  }

  static double _firstDouble(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value is double) return value;
      if (value is num) return value.toDouble();

      if (value is String) {
        final parsed = double.tryParse(
          value.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        if (parsed != null) return parsed;
      }
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
