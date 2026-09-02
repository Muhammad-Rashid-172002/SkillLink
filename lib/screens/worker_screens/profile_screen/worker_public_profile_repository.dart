import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class PublicWorkerReview {
  const PublicWorkerReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.customerName,
    required this.customerPhotoUrl,
    required this.createdAt,
    required this.service,
    required this.verifiedBooking,
  });

  final String id;
  final double rating;
  final String comment;
  final String customerName;
  final String customerPhotoUrl;
  final DateTime? createdAt;
  final String service;
  final bool verifiedBooking;
}

abstract interface class WorkerPublicProfileDataSource {
  Stream<Map<String, dynamic>?> watchWorker(String workerId);
  Stream<List<PublicWorkerReview>> watchReviews(String workerId);
  Future<void> refresh(String workerId);
}

class FirebaseWorkerPublicProfileDataSource
    implements WorkerPublicProfileDataSource {
  FirebaseWorkerPublicProfileDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, Map<String, dynamic>> _customerCache = {};
  final Map<String, Map<String, dynamic>> _requestCache = {};

  @override
  Stream<Map<String, dynamic>?> watchWorker(String workerId) {
    return _firestore
        .collection('users')
        .doc(workerId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Stream<List<PublicWorkerReview>> watchReviews(String workerId) {
    return _firestore
        .collection('reviews')
        .where('workerId', isEqualTo: workerId)
        .limit(30)
        .snapshots()
        .asyncMap((snapshot) => _hydrateReviews(workerId, snapshot.docs));
  }

  Future<List<PublicWorkerReview>> _hydrateReviews(
    String workerId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) async {
    final visible = documents
        .where((document) {
          final data = document.data();
          final rating = _number(data['rating']);
          final state = data['status']?.toString().trim().toLowerCase() ?? '';
          return data['workerId'] == workerId &&
              data['isHidden'] != true &&
              data['isDeleted'] != true &&
              state != 'deleted' &&
              rating != null &&
              rating >= 1 &&
              rating <= 5;
        })
        .toList(growable: false);

    final customerIds = visible
        .map((document) => _text(document.data()['customerId']))
        .where((id) => id.isNotEmpty && !_customerCache.containsKey(id))
        .toSet();
    final requestIds = visible
        .map((document) => _text(document.data()['requestId']))
        .where((id) => id.isNotEmpty && !_requestCache.containsKey(id))
        .toSet();

    await Future.wait([
      _loadDocuments('users', customerIds, _customerCache),
      _loadDocuments('requests', requestIds, _requestCache),
    ]);

    final reviews = visible.map((document) {
      final data = document.data();
      final customerId = _text(data['customerId']);
      final requestId = _text(data['requestId']);
      final customer = _customerCache[customerId] ?? const <String, dynamic>{};
      final request = _requestCache[requestId] ?? const <String, dynamic>{};
      final requestMatches =
          request['status'] == 'completed' &&
          request['workerId'] == workerId &&
          request['customerId'] == customerId;
      final timestamp = data['createdAt'];

      return PublicWorkerReview(
        id: document.id,
        rating: _number(data['rating']) ?? 0,
        comment: _firstText(data, const ['review', 'comment']),
        customerName: _firstText(
          customer,
          const ['name', 'displayName'],
          fallback: _firstText(data, const [
            'customerName',
            'reviewerName',
          ], fallback: 'SkillNova customer'),
        ),
        customerPhotoUrl: _firstText(customer, const [
          'profileImage',
          'profileImageUrl',
          'photoUrl',
        ]),
        createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
        service: _firstText(request, const [
          'category',
          'serviceName',
        ], fallback: _firstText(data, const ['category', 'service'])),
        verifiedBooking: requestMatches,
      );
    }).toList();

    reviews.sort((a, b) {
      final first = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final second = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return second.compareTo(first);
    });
    return reviews;
  }

  Future<void> _loadDocuments(
    String collection,
    Set<String> ids,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    final values = ids.toList();
    for (var start = 0; start < values.length; start += 30) {
      final end = math.min(start + 30, values.length);
      final chunk = values.sublist(start, end);
      if (chunk.isEmpty) continue;
      final snapshot = await _firestore
          .collection(collection)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final document in snapshot.docs) {
        cache[document.id] = document.data();
      }
      for (final id in chunk) {
        cache.putIfAbsent(id, () => const <String, dynamic>{});
      }
    }
  }

  @override
  Future<void> refresh(String workerId) async {
    _customerCache.clear();
    _requestCache.clear();
    await Future.wait([
      _firestore.collection('users').doc(workerId).get(),
      _firestore
          .collection('reviews')
          .where('workerId', isEqualTo: workerId)
          .limit(30)
          .get(),
    ]);
  }
}

String _text(dynamic value) => value?.toString().trim() ?? '';

String _firstText(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = _text(data[key]);
    if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
  }
  return fallback;
}

double? _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
