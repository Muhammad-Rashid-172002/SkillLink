import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewManagementService {
  ReviewManagementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('reviews');

  Stream<QuerySnapshot<Map<String, dynamic>>> reviewsStream() {
    return _reviews.snapshots();
  }

  Future<void> setReviewHidden({
    required String reviewId,
    required bool isHidden,
  }) async {
    await _reviews.doc(reviewId).update({
      'isHidden': isHidden,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setReviewFlagged({
    required String reviewId,
    required bool isFlagged,
  }) async {
    await _reviews.doc(reviewId).update({
      'isFlagged': isFlagged,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReview(String reviewId) async {
    await _reviews.doc(reviewId).delete();
  }
}

class ManagedReview {
  const ManagedReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.customerName,
    required this.customerEmail,
    required this.workerName,
    required this.workerEmail,
    required this.jobTitle,
    required this.isHidden,
    required this.isFlagged,
    required this.createdAt,
    required this.rawData,
  });

  final String id;
  final double rating;
  final String comment;
  final String customerName;
  final String customerEmail;
  final String workerName;
  final String workerEmail;
  final String jobTitle;
  final bool isHidden;
  final bool isFlagged;
  final DateTime? createdAt;
  final Map<String, dynamic> rawData;

  factory ManagedReview.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return ManagedReview(
      id: document.id,
      rating: _firstDouble(
        data,
        const ['rating', 'stars', 'score'],
      ),
      comment: _firstString(
        data,
        const ['comment', 'review', 'message', 'feedback'],
        fallback: 'No written feedback',
      ),
      customerName: _firstString(
        data,
        const ['customerName', 'reviewerName', 'userName', 'name'],
        fallback: 'Customer',
      ),
      customerEmail: _firstString(
        data,
        const ['customerEmail', 'reviewerEmail', 'userEmail'],
        fallback: 'No email',
      ),
      workerName: _firstString(
        data,
        const ['workerName', 'providerName'],
        fallback: 'Worker',
      ),
      workerEmail: _firstString(
        data,
        const ['workerEmail', 'providerEmail'],
        fallback: 'No email',
      ),
      jobTitle: _firstString(
        data,
        const ['jobTitle', 'serviceName', 'category', 'title'],
        fallback: 'Service Job',
      ),
      isHidden: _firstBool(
        data,
        const ['isHidden', 'hidden'],
      ),
      isFlagged: _firstBool(
        data,
        const ['isFlagged', 'flagged', 'reported'],
      ),
      createdAt: _firstDate(
        data,
        const ['createdAt', 'submittedAt', 'date'],
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

  static double _firstDouble(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
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
