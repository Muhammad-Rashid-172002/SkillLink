import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';

abstract interface class WorkerHomeRepository {
  String? get currentWorkerId;
  Stream<WorkerHomeProfile> watchProfile();
  Stream<WorkerActiveJobsSnapshot> watchActiveJobs();
  Stream<List<WorkerLeadPreview>> watchLeads(WorkerHomeProfile worker);
}

class FirebaseWorkerHomeRepository implements WorkerHomeRepository {
  FirebaseWorkerHomeRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Map<String, Future<String>> _customerNames = {};

  @override
  String? get currentWorkerId => _auth.currentUser?.uid;

  String get _uid {
    final value = currentWorkerId;
    if (value == null) throw StateError('Please sign in again.');
    return value;
  }

  @override
  Stream<WorkerHomeProfile> watchProfile() {
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

  @override
  Stream<WorkerActiveJobsSnapshot> watchActiveJobs() {
    return _firestore
        .collection('requests')
        .where('workerId', isEqualTo: _uid)
        .where(
          'status',
          whereIn: const ['accepted', 'on_the_way', 'in_progress'],
        )
        .limit(5)
        .snapshots()
        .asyncMap((snapshot) async {
          final jobs =
              snapshot.docs
                  .map(
                    (document) =>
                        WorkerActiveJob(id: document.id, data: document.data()),
                  )
                  .toList(growable: false)
                ..sort((first, second) {
                  final priority = second.priority.compareTo(first.priority);
                  if (priority != 0) return priority;
                  final firstDate =
                      first.acceptedAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final secondDate =
                      second.acceptedAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return secondDate.compareTo(firstDate);
                });
          if (jobs.isEmpty) return const WorkerActiveJobsSnapshot();
          final featured = jobs.first;
          final embeddedName = workerText(featured.data, const [
            'customerName',
            'clientName',
          ]);
          final customerName = embeddedName.isNotEmpty
              ? embeddedName
              : await _customerName(
                  workerText(featured.data, const ['customerId']),
                );
          return WorkerActiveJobsSnapshot(
            featured: WorkerActiveJob(
              id: featured.id,
              data: featured.data,
              customerName: customerName,
            ),
            hasAdditionalJobs: jobs.length > 1,
          );
        });
  }

  @override
  Stream<List<WorkerLeadPreview>> watchLeads(WorkerHomeProfile worker) {
    if (worker.querySkill.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'searching')
        .limit(30)
        .snapshots()
        .map((snapshot) {
          final leads =
              snapshot.docs
                  .map(
                    (document) => WorkerLeadPreview(
                      id: document.id,
                      data: document.data(),
                    ),
                  )
                  .where((lead) => lead.isEligibleFor(worker))
                  .map((lead) {
                    final requestCoordinate = WorkerCoordinate.from(
                      lead.data['customerLocation'],
                      latitude: lead.data['latitude'] ?? lead.data['lat'],
                      longitude: lead.data['longitude'] ?? lead.data['lng'],
                    );
                    final workerCoordinate = worker.coordinate;
                    return lead.withDistance(
                      workerCoordinate == null || requestCoordinate == null
                          ? null
                          : workerDistanceKm(
                              workerCoordinate,
                              requestCoordinate,
                            ),
                    );
                  })
                  .toList(growable: false)
                ..sort((first, second) {
                  final firstDate =
                      first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final secondDate =
                      second.createdAt ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return secondDate.compareTo(firstDate);
                });
          return leads.take(4).toList(growable: false);
        });
  }

  Future<String> _customerName(String customerId) {
    if (customerId.isEmpty) return Future.value('Customer');
    return _customerNames.putIfAbsent(customerId, () async {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(customerId)
            .get();
        return workerText(snapshot.data() ?? const {}, const [
          'name',
          'fullName',
          'displayName',
        ], fallback: 'Customer');
      } on FirebaseException {
        return 'Customer';
      }
    });
  }
}
