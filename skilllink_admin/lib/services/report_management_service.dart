import 'package:cloud_firestore/cloud_firestore.dart';

class ReportManagementService {
  ReportManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  Stream<QuerySnapshot<Map<String, dynamic>>> reportsStream() {
    return _reports.snapshots();
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? resolutionNote,
  }) async {
    await _reports.doc(reportId).update({
      'status': status,
      'resolutionNote': resolutionNote?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'resolved') 'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignPriority({
    required String reportId,
    required String priority,
  }) async {
    await _reports.doc(reportId).update({
      'priority': priority,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReport(String reportId) async {
    await _reports.doc(reportId).delete();
  }
}

class ManagedReport {
  const ManagedReport({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.priority,
    required this.reporterName,
    required this.reporterEmail,
    required this.reportedUserName,
    required this.reportedUserEmail,
    required this.jobTitle,
    required this.createdAt,
    required this.resolutionNote,
    required this.rawData,
  });

  final String id;
  final String title;
  final String description;
  final String type;
  final String status;
  final String priority;
  final String reporterName;
  final String reporterEmail;
  final String reportedUserName;
  final String reportedUserEmail;
  final String jobTitle;
  final DateTime? createdAt;
  final String resolutionNote;
  final Map<String, dynamic> rawData;

  bool get isOpen => const {'open', 'pending', 'new'}.contains(status);
  bool get isInvestigating =>
      const {'investigating', 'in_review', 'reviewing'}.contains(status);
  bool get isResolved => status == 'resolved';
  bool get isRejected => const {'rejected', 'dismissed'}.contains(status);

  factory ManagedReport.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return ManagedReport(
      id: document.id,
      title: _firstString(
        data,
        const ['title', 'subject', 'reason'],
        fallback: 'User Complaint',
      ),
      description: _firstString(
        data,
        const ['description', 'details', 'message', 'complaint'],
        fallback: 'No description provided',
      ),
      type: _firstString(
        data,
        const ['type', 'category', 'reportType'],
        fallback: 'general',
      ).toLowerCase(),
      status: _firstString(
        data,
        const ['status'],
        fallback: 'open',
      ).toLowerCase(),
      priority: _firstString(
        data,
        const ['priority', 'severity'],
        fallback: 'medium',
      ).toLowerCase(),
      reporterName: _firstString(
        data,
        const ['reporterName', 'customerName', 'userName', 'submittedByName'],
        fallback: 'Reporter',
      ),
      reporterEmail: _firstString(
        data,
        const ['reporterEmail', 'customerEmail', 'userEmail'],
        fallback: 'No email',
      ),
      reportedUserName: _firstString(
        data,
        const ['reportedUserName', 'workerName', 'targetUserName'],
        fallback: 'Not specified',
      ),
      reportedUserEmail: _firstString(
        data,
        const ['reportedUserEmail', 'workerEmail', 'targetUserEmail'],
        fallback: 'No email',
      ),
      jobTitle: _firstString(
        data,
        const ['jobTitle', 'serviceName', 'category'],
        fallback: 'Not linked',
      ),
      createdAt: _firstDate(
        data,
        const ['createdAt', 'reportedAt', 'submittedAt'],
      ),
      resolutionNote: _firstString(
        data,
        const ['resolutionNote', 'adminNote', 'note'],
        fallback: '',
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
