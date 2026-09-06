import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_models.dart';

abstract interface class WorkerLeadsRepository {
  String? get currentWorkerId;
  Stream<WorkerHomeProfile> watchWorker();
  Stream<List<WorkerLead>> watchLeads(WorkerHomeProfile worker);
  Stream<WorkerLead?> watchLead(String requestId, WorkerHomeProfile worker);
  Future<void> refresh(WorkerHomeProfile worker);
  Future<void> acceptLead(String requestId);
}

class FirebaseWorkerLeadsRepository implements WorkerLeadsRepository {
  FirebaseWorkerLeadsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Map<String, WorkerLeadCustomer> _customerCache = {};

  @override
  String? get currentWorkerId => _auth.currentUser?.uid;

  String get _uid {
    final uid = currentWorkerId;
    if (uid == null || uid.isEmpty) {
      throw const WorkerLeadAcceptanceException(
        WorkerLeadAcceptanceFailure.signedOut,
        'Please sign in again before accepting a lead.',
      );
    }
    return uid;
  }

  @override
  Stream<WorkerHomeProfile> watchWorker() {
    final uid = _uid;
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map(
          (snapshot) => WorkerHomeProfile(
            uid: uid,
            data: snapshot.data() ?? const <String, dynamic>{},
          ),
        );
  }

  Query<Map<String, dynamic>> _leadQuery(WorkerHomeProfile worker) {
    final categories = workerLeadCategoryQueryValues(worker.querySkill);
    Query<Map<String, dynamic>> query = _firestore
        .collection('requests')
        .where('status', isEqualTo: 'searching');
    query = categories.length == 1
        ? query.where('category', isEqualTo: categories.single)
        : query.where('category', whereIn: categories);
    return query.orderBy('createdAt', descending: true).limit(60);
  }

  @override
  Stream<List<WorkerLead>> watchLeads(WorkerHomeProfile worker) {
    if (worker.querySkill.isEmpty) return Stream.value(const []);
    return _leadQuery(worker).snapshots().asyncMap((snapshot) async {
      final visible = snapshot.docs
          .map((document) => WorkerLead(id: document.id, data: document.data()))
          .where((lead) => lead.isVisibleTo(worker))
          .toList(growable: false);
      await _hydrateCustomers(visible.map((lead) => lead.customerId));
      return visible
          .map((lead) {
            final requestPoint = lead.coordinate;
            final workerPoint = worker.coordinate;
            final distance = workerPoint == null || requestPoint == null
                ? null
                : workerDistanceKm(workerPoint, requestPoint);
            return lead.copyWith(
              customer: _customerCache[lead.customerId],
              distanceKm: distance,
              preserveDistance: false,
            );
          })
          .toList(growable: false);
    });
  }

  @override
  Stream<WorkerLead?> watchLead(String requestId, WorkerHomeProfile worker) {
    return _firestore
        .collection('requests')
        .doc(requestId)
        .snapshots()
        .asyncMap((snapshot) async {
          final data = snapshot.data();
          if (data == null) return null;
          final lead = WorkerLead(id: snapshot.id, data: data);
          await _hydrateCustomers([lead.customerId]);
          final requestPoint = lead.coordinate;
          final workerPoint = worker.coordinate;
          return lead.copyWith(
            customer: _customerCache[lead.customerId],
            distanceKm: workerPoint == null || requestPoint == null
                ? null
                : workerDistanceKm(workerPoint, requestPoint),
            preserveDistance: false,
          );
        });
  }

  @override
  Future<void> refresh(WorkerHomeProfile worker) async {
    await Future.wait([
      _firestore.collection('users').doc(_uid).get(),
      if (worker.querySkill.isNotEmpty) _leadQuery(worker).get(),
    ]);
  }

  @override
  Future<void> acceptLead(String requestId) async {
    final uid = _uid;
    final workerRef = _firestore.collection('users').doc(uid);
    final requestRef = _firestore.collection('requests').doc(requestId);
    final transactionRef = _firestore
        .collection('transactions')
        .doc('lead_${requestId}_$uid');

    try {
      await _firestore.runTransaction((transaction) async {
        final workerSnapshot = await transaction.get(workerRef);
        final requestSnapshot = await transaction.get(requestRef);
        final workerData = workerSnapshot.data();
        final requestData = requestSnapshot.data();

        final plan = planWorkerLeadAcceptance(
          workerId: uid,
          workerData: workerData,
          requestId: requestId,
          requestData: requestData,
        );

        transaction.update(workerRef, {
          'credits': plan.balanceAfter,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(requestRef, {
          'status': plan.nextStatus,
          'workerId': plan.workerId,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(transactionRef, {
          'workerId': uid,
          'requestId': requestId,
          'title': 'Used 1 lead credit',
          'amount': '-1 Credit',
          'type': 'lead_used',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on WorkerLeadAcceptanceException {
      rethrow;
    } on FirebaseException catch (error) {
      final network =
          error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed';
      throw WorkerLeadAcceptanceException(
        network
            ? WorkerLeadAcceptanceFailure.network
            : WorkerLeadAcceptanceFailure.unknown,
        network
            ? 'Check your connection and try again.'
            : 'The lead could not be accepted. Please try again.',
      );
    } catch (_) {
      throw const WorkerLeadAcceptanceException(
        WorkerLeadAcceptanceFailure.unknown,
        'The lead could not be accepted. Please try again.',
      );
    }
  }

  Future<void> _hydrateCustomers(Iterable<String> ids) async {
    final missing = ids
        .where((id) => id.isNotEmpty && !_customerCache.containsKey(id))
        .toSet()
        .toList(growable: false);
    for (var offset = 0; offset < missing.length; offset += 10) {
      final end = (offset + 10).clamp(0, missing.length);
      final chunk = missing.sublist(offset, end);
      try {
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final document in snapshot.docs) {
          _customerCache[document.id] = WorkerLeadCustomer.from(
            document.id,
            document.data(),
          );
        }
      } on FirebaseException {
        // Lead discovery remains usable when public customer summaries fail.
      }
    }
  }
}
