import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';

class WorkerJobChatDestination {
  const WorkerJobChatDestination({
    required this.chatId,
    required this.customerId,
    required this.customerName,
    required this.service,
  });

  final String chatId;
  final String customerId;
  final String customerName;
  final String service;
}

String deterministicWorkerRequestChatId(String requestId) =>
    'request_$requestId';

bool isValidWorkerRequestChat({
  required Map<String, dynamic>? data,
  required String workerId,
  required String customerId,
  required String requestId,
}) {
  if (data == null ||
      workerText(data, const ['workerId']) != workerId ||
      workerText(data, const ['customerId']) != customerId) {
    return false;
  }
  final linkedRequest = workerText(data, const ['requestId']);
  return linkedRequest.isEmpty || linkedRequest == requestId;
}

enum WorkerLocationUpdateResult { shared, permissionDenied, serviceDisabled }

abstract interface class WorkerJobsRepository {
  String? get currentWorkerId;
  Stream<List<WorkerJob>> watchJobs(WorkerJobGroup group);
  Stream<WorkerJob?> watchJob(String requestId);
  Stream<WorkerCoordinate?> watchWorkerCoordinate();
  Future<void> refreshJobs(WorkerJobGroup group);
  Future<void> transitionJob({
    required String requestId,
    required WorkerJobStatus expectedStatus,
    required WorkerJobStatus nextStatus,
  });
  Future<WorkerLocationUpdateResult> shareLocation(String requestId);
  Future<WorkerJobChatDestination> resolveChat(WorkerJob job);
}

class FirebaseWorkerJobsRepository implements WorkerJobsRepository {
  FirebaseWorkerJobsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Map<String, WorkerJobCustomer> _customerCache = {};
  final Map<String, WorkerJobReview?> _reviewCache = {};

  @override
  String? get currentWorkerId => _auth.currentUser?.uid;

  String get _uid {
    final uid = currentWorkerId;
    if (uid == null || uid.isEmpty) {
      throw const WorkerJobTransitionException(
        WorkerJobTransitionFailure.signedOut,
        'Please sign in again before managing jobs.',
      );
    }
    return uid;
  }

  Query<Map<String, dynamic>> _jobsQuery(WorkerJobGroup group) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('requests')
        .where('workerId', isEqualTo: _uid);
    query = switch (group) {
      WorkerJobGroup.active => query.where(
        'status',
        whereIn: workerJobQueryStatuses(group),
      ),
      WorkerJobGroup.completed => query.where('status', isEqualTo: 'completed'),
      WorkerJobGroup.cancelled => query.where(
        'status',
        whereIn: workerJobQueryStatuses(group),
      ),
    };
    final limit = workerJobQueryLimits[group]!;
    return query.orderBy('createdAt', descending: true).limit(limit);
  }

  @override
  Stream<List<WorkerJob>> watchJobs(WorkerJobGroup group) {
    return _jobsQuery(group).snapshots().asyncMap((snapshot) async {
      final jobs = snapshot.docs
          .map((document) => WorkerJob(id: document.id, data: document.data()))
          .where((job) => isWorkerJobInGroup(job, _uid, group))
          .toList(growable: false);
      await _hydrateCustomers(jobs.map((job) => job.customerId));
      if (group == WorkerJobGroup.completed) {
        await _hydrateReviews(jobs.map((job) => job.id));
      }
      final workerPoint = await _workerCoordinate();
      final hydrated = jobs
          .map((job) {
            final servicePoint = job.serviceCoordinate;
            return job.copyWith(
              customer: _customerCache[job.customerId],
              review: group == WorkerJobGroup.completed
                  ? _reviewCache[job.id]
                  : null,
              preserveReview: false,
              distanceKm: workerPoint == null || servicePoint == null
                  ? null
                  : workerDistanceKm(workerPoint, servicePoint),
              preserveDistance: false,
            );
          })
          .toList(growable: false);
      hydrated.sort((first, second) {
        final a = first.relevantDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final b = second.relevantDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return b.compareTo(a);
      });
      return hydrated;
    });
  }

  @override
  Stream<WorkerJob?> watchJob(String requestId) {
    return _firestore
        .collection('requests')
        .doc(requestId)
        .snapshots()
        .asyncMap((snapshot) async {
          final data = snapshot.data();
          if (data == null) return null;
          final job = WorkerJob(id: snapshot.id, data: data);
          if (job.workerId != _uid ||
              job.status.status == WorkerJobStatus.unknown) {
            return job;
          }
          await _hydrateCustomers([job.customerId]);
          WorkerJobReview? review;
          if (job.status.status == WorkerJobStatus.completed ||
              data['reviewed'] == true) {
            final reviewSnapshot = await _firestore
                .collection('reviews')
                .doc(requestId)
                .get();
            final reviewData = reviewSnapshot.data();
            if (reviewData != null &&
                workerText(reviewData, const ['workerId']) == _uid &&
                (workerText(reviewData, const ['requestId']).isEmpty ||
                    workerText(reviewData, const ['requestId']) == requestId)) {
              review = WorkerJobReview.from(reviewData);
            }
          }
          final workerPoint = await _workerCoordinate();
          final servicePoint = job.serviceCoordinate;
          return job.copyWith(
            customer: _customerCache[job.customerId],
            review: review,
            preserveReview: false,
            distanceKm: workerPoint == null || servicePoint == null
                ? null
                : workerDistanceKm(workerPoint, servicePoint),
            preserveDistance: false,
          );
        });
  }

  @override
  Stream<WorkerCoordinate?> watchWorkerCoordinate() {
    return _firestore.collection('users').doc(_uid).snapshots().map((snapshot) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      return WorkerCoordinate.from(
        data['currentLocation'] ?? data['geoPoint'],
        latitude: data['lat'] ?? data['latitude'],
        longitude: data['lng'] ?? data['longitude'],
      );
    });
  }

  @override
  Future<void> refreshJobs(WorkerJobGroup group) async {
    _customerCache.clear();
    _reviewCache.clear();
    await _jobsQuery(group).get();
  }

  @override
  Future<void> transitionJob({
    required String requestId,
    required WorkerJobStatus expectedStatus,
    required WorkerJobStatus nextStatus,
  }) async {
    final requestRef = _firestore.collection('requests').doc(requestId);
    try {
      await _firestore.runTransaction((transaction) async {
        final requestSnapshot = await transaction.get(requestRef);
        final plan = planWorkerJobTransition(
          authenticatedWorkerId: _uid,
          requestData: requestSnapshot.data(),
          expectedStatus: expectedStatus,
          requestedStatus: nextStatus,
        );
        final update = <String, dynamic>{
          'status': plan.firestoreValue,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        switch (nextStatus) {
          case WorkerJobStatus.onTheWay:
            update['onTheWayAt'] = FieldValue.serverTimestamp();
          case WorkerJobStatus.inProgress:
            update['startedAt'] = FieldValue.serverTimestamp();
          case WorkerJobStatus.completed:
            update.addAll({
              'completedAt': FieldValue.serverTimestamp(),
              'reviewPending': true,
              'reviewed': false,
            });
          case WorkerJobStatus.accepted ||
              WorkerJobStatus.cancelled ||
              WorkerJobStatus.unknown:
            break;
        }
        transaction.update(requestRef, update);
      });
    } on WorkerJobTransitionException {
      rethrow;
    } on FirebaseException catch (error) {
      final network =
          error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed';
      throw WorkerJobTransitionException(
        network
            ? WorkerJobTransitionFailure.network
            : WorkerJobTransitionFailure.unknown,
        network
            ? 'Check your connection and try again.'
            : 'The job could not be updated. Please try again.',
      );
    } catch (_) {
      throw const WorkerJobTransitionException(
        WorkerJobTransitionFailure.unknown,
        'The job could not be updated. Please try again.',
      );
    }
  }

  @override
  Future<WorkerLocationUpdateResult> shareLocation(String requestId) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return WorkerLocationUpdateResult.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return WorkerLocationUpdateResult.permissionDenied;
    }
    final position = await Geolocator.getCurrentPosition();
    final requestRef = _firestore.collection('requests').doc(requestId);
    final workerRef = _firestore.collection('users').doc(_uid);
    await _firestore.runTransaction((transaction) async {
      final request = await transaction.get(requestRef);
      final data = request.data();
      if (data == null ||
          workerText(data, const ['workerId']) != _uid ||
          workerJobStatusOf(data['status']).status !=
              WorkerJobStatus.onTheWay) {
        throw const WorkerJobTransitionException(
          WorkerJobTransitionFailure.stale,
          'Location sharing stopped because this job is no longer on the way.',
        );
      }
      transaction.update(workerRef, {
        'lat': position.latitude,
        'lng': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
    return WorkerLocationUpdateResult.shared;
  }

  @override
  Future<WorkerJobChatDestination> resolveChat(WorkerJob job) async {
    final uid = _uid;
    if (job.workerId != uid || job.customerId.isEmpty) {
      throw const WorkerJobTransitionException(
        WorkerJobTransitionFailure.wrongWorker,
        'Messaging is unavailable for this job.',
      );
    }
    final historical = await _firestore
        .collection('chats')
        .where('requestId', isEqualTo: job.id)
        .limit(10)
        .get();
    String? historicalId;
    for (final document in historical.docs) {
      if (isValidWorkerRequestChat(
        data: document.data(),
        workerId: uid,
        customerId: job.customerId,
        requestId: job.id,
      )) {
        historicalId = document.id;
        break;
      }
    }
    final historicalCandidate = historicalId;
    final requestRef = _firestore.collection('requests').doc(job.id);
    final resolvedId = await _firestore.runTransaction<String>((
      transaction,
    ) async {
      final request = await transaction.get(requestRef);
      final requestData = request.data();
      if (requestData == null ||
          workerText(requestData, const ['workerId']) != uid ||
          workerText(requestData, const ['customerId']) != job.customerId) {
        throw const WorkerJobTransitionException(
          WorkerJobTransitionFailure.stale,
          'Messaging is unavailable because this job changed.',
        );
      }

      final linkedId = workerText(requestData, const ['chatId']);
      if (linkedId.isNotEmpty) {
        final linked = await transaction.get(
          _firestore.collection('chats').doc(linkedId),
        );
        if (!isValidWorkerRequestChat(
          data: linked.data(),
          workerId: uid,
          customerId: job.customerId,
          requestId: job.id,
        )) {
          throw const WorkerJobTransitionException(
            WorkerJobTransitionFailure.stale,
            'Messaging is unavailable because this job changed.',
          );
        }
        return linkedId;
      }

      if (historicalCandidate != null) {
        final historicalChat = await transaction.get(
          _firestore.collection('chats').doc(historicalCandidate),
        );
        if (isValidWorkerRequestChat(
          data: historicalChat.data(),
          workerId: uid,
          customerId: job.customerId,
          requestId: job.id,
        )) {
          transaction.update(requestRef, {
            'chatId': historicalCandidate,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return historicalCandidate;
        }
      }

      final deterministicId = deterministicWorkerRequestChatId(job.id);
      final chatRef = _firestore.collection('chats').doc(deterministicId);
      final chat = await transaction.get(chatRef);
      if (chat.exists &&
          !isValidWorkerRequestChat(
            data: chat.data(),
            workerId: uid,
            customerId: job.customerId,
            requestId: job.id,
          )) {
        throw const WorkerJobTransitionException(
          WorkerJobTransitionFailure.stale,
          'Messaging is unavailable because this job changed.',
        );
      }
      if (!chat.exists) {
        transaction.set(chatRef, {
          'participants': [job.customerId, uid],
          'customerId': job.customerId,
          'workerId': uid,
          'requestId': job.id,
          'service': job.category,
          'lastMessage': '',
          'customerUnreadCount': 0,
          'unreadCountCustomer': 0,
          'workerUnreadCount': 0,
          'unreadCountWorker': 0,
          'archivedByCustomer': false,
          'archivedByWorker': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.update(requestRef, {
        'chatId': deterministicId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return deterministicId;
    });
    return _chatDestination(resolvedId, job);
  }

  WorkerJobChatDestination _chatDestination(String chatId, WorkerJob job) {
    return WorkerJobChatDestination(
      chatId: chatId,
      customerId: job.customerId,
      customerName: job.customer?.name ?? 'Customer',
      service: job.category,
    );
  }

  Future<WorkerCoordinate?> _workerCoordinate() async {
    final snapshot = await _firestore.collection('users').doc(_uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return WorkerCoordinate.from(
      data['currentLocation'] ?? data['geoPoint'],
      latitude: data['lat'] ?? data['latitude'],
      longitude: data['lng'] ?? data['longitude'],
    );
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
          _customerCache[document.id] = WorkerJobCustomer.from(
            document.id,
            document.data(),
          );
        }
      } on FirebaseException {
        // A missing public customer summary must not hide the worker's job.
      }
    }
  }

  Future<void> _hydrateReviews(Iterable<String> ids) async {
    final missing = ids
        .where((id) => id.isNotEmpty && !_reviewCache.containsKey(id))
        .toSet()
        .toList(growable: false);
    for (var offset = 0; offset < missing.length; offset += 10) {
      final end = (offset + 10).clamp(0, missing.length);
      final chunk = missing.sublist(offset, end);
      for (final id in chunk) {
        _reviewCache[id] = null;
      }
      try {
        final snapshot = await _firestore
            .collection('reviews')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final document in snapshot.docs) {
          final data = document.data();
          if (workerText(data, const ['workerId']) == _uid &&
              (workerText(data, const ['requestId']).isEmpty ||
                  workerText(data, const ['requestId']) == document.id)) {
            _reviewCache[document.id] = WorkerJobReview.from(data);
          }
        }
      } on FirebaseException {
        // Jobs remain usable when optional review summaries cannot load.
      }
    }
  }
}
