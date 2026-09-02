import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'booking_models.dart';
import 'booking_status.dart';

abstract interface class CustomerBookingsDataSource {
  String get customerId;
  Stream<List<CustomerBooking>> watchBookings();
  Future<void> refreshBookings();
  Future<void> cancelPreServiceRequest(String requestId);
}

abstract interface class BookingDetailDataSource {
  Stream<Map<String, dynamic>?> watchRequest(String requestId);
  Stream<Map<String, dynamic>?> watchWorker(String workerId);
  Stream<Map<String, dynamic>?> watchReview(String requestId);
  Future<void> refreshBooking(String requestId, {String? workerId});
  Future<void> cancelPreServiceRequest(String requestId);
}

class FirebaseCustomerBookingsRepository
    implements CustomerBookingsDataSource, BookingDetailDataSource {
  FirebaseCustomerBookingsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Map<String, Map<String, dynamic>> _workerCache = {};
  final Map<String, Map<String, dynamic>> _reviewCache = {};

  @override
  String get customerId => _auth.currentUser?.uid ?? '';

  Query<Map<String, dynamic>> get _bookingsQuery => _firestore
      .collection('requests')
      .where('customerId', isEqualTo: customerId)
      .limit(100);

  @override
  Stream<List<CustomerBooking>> watchBookings() {
    return _bookingsQuery.snapshots().asyncMap((snapshot) async {
      final workerIds = snapshot.docs
          .map((document) => bookingText(document.data(), const ['workerId']))
          .where((id) => id.isNotEmpty && !_workerCache.containsKey(id))
          .toSet();
      final completedIds = snapshot.docs
          .where(
            (document) =>
                bookingStatusOf(document.data()['status']).group ==
                BookingGroup.completed,
          )
          .map((document) => document.id)
          .where((id) => !_reviewCache.containsKey(id))
          .toSet();

      await Future.wait([
        _loadByIds('users', workerIds, _workerCache),
        _loadByIds('reviews', completedIds, _reviewCache),
      ]);

      final bookings = snapshot.docs
          .map((document) {
            final data = document.data();
            final workerId = bookingText(data, const ['workerId']);
            return CustomerBooking(
              id: document.id,
              data: data,
              worker: _nonEmpty(_workerCache[workerId]),
              review: _nonEmpty(_reviewCache[document.id]),
            );
          })
          .toList(growable: false);
      bookings.sort((first, second) {
        final firstDate =
            first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final secondDate =
            second.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return secondDate.compareTo(firstDate);
      });
      return bookings;
    });
  }

  @override
  Stream<Map<String, dynamic>?> watchRequest(String requestId) {
    return _firestore
        .collection('requests')
        .doc(requestId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Stream<Map<String, dynamic>?> watchWorker(String workerId) {
    if (workerId.isEmpty) return Stream.value(null);
    return _firestore
        .collection('users')
        .doc(workerId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Stream<Map<String, dynamic>?> watchReview(String requestId) {
    return _firestore
        .collection('reviews')
        .doc(requestId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Future<void> refreshBookings() async {
    _workerCache.clear();
    _reviewCache.clear();
    await _bookingsQuery.get();
  }

  @override
  Future<void> refreshBooking(String requestId, {String? workerId}) async {
    await Future.wait([
      _firestore.collection('requests').doc(requestId).get(),
      _firestore.collection('reviews').doc(requestId).get(),
      if (workerId != null && workerId.isNotEmpty)
        _firestore.collection('users').doc(workerId).get(),
    ]);
  }

  @override
  Future<void> cancelPreServiceRequest(String requestId) async {
    final uid = customerId;
    if (uid.isEmpty) throw StateError('Please sign in again.');
    final reference = _firestore.collection('requests').doc(requestId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) throw StateError('This request no longer exists.');
      if (bookingText(data, const ['customerId']) != uid) {
        throw StateError('You cannot cancel this request.');
      }
      if (!canCancelBookingStatus(data['status'])) {
        throw StateError(
          'This request can no longer be cancelled from the app.',
        );
      }
      transaction.update(reference, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _loadByIds(
    String collection,
    Set<String> ids,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    final values = ids.toList(growable: false);
    for (var start = 0; start < values.length; start += 30) {
      final end = math.min(start + 30, values.length);
      final chunk = values.sublist(start, end);
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

  Map<String, dynamic>? _nonEmpty(Map<String, dynamic>? value) {
    return value == null || value.isEmpty ? null : value;
  }
}
