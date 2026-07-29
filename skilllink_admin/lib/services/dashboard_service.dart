import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilllink_admin/models/dashboard_stats.dart';

class DashboardService {
  DashboardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<int> _countCollection(
    String collection, {
    Query<Map<String, dynamic>>? query,
  }) async {
    final target = query ?? _firestore.collection(collection);
    final snapshot = await target.count().get();
    return snapshot.count ?? 0;
  }

  Future<DashboardStats> loadStats() async {
    final users = _firestore.collection('users');
    final requests = _firestore.collection('requests');
    final emergencyAlerts = _firestore.collection('emergency_alerts');

    final results = await Future.wait<int>([
      _countCollection('users'),
      _countCollection(
        'users',
        query: users.where('role', isEqualTo: 'worker'),
      ),
      _countCollection(
        'users',
        query: users.where('role', isEqualTo: 'customer'),
      ),
      _countCollection('requests'),
      _countCollection(
        'requests',
        query: requests.where('status', isEqualTo: 'pending'),
      ),
      _countActiveJobs(requests),
      _countCollection(
        'requests',
        query: requests.where('status', isEqualTo: 'completed'),
      ),
      _countCollection('reviews'),
      _countCollection('transactions'),
      _countCollection('emergency_alerts'),
      _countCollection(
        'emergency_alerts',
        query: emergencyAlerts.where(
          'status',
          whereIn: const ['active', 'investigating'],
        ),
      ),
    ]);

    return DashboardStats(
      totalUsers: results[0],
      totalWorkers: results[1],
      totalCustomers: results[2],
      totalJobs: results[3],
      pendingJobs: results[4],
      activeJobs: results[5],
      completedJobs: results[6],
      totalReviews: results[7],
      totalTransactions: results[8],
      totalEmergencyAlerts: results[9],
      activeEmergencyAlerts: results[10],
    );
  }

  Future<int> _countActiveJobs(
    CollectionReference<Map<String, dynamic>> requests,
  ) async {
    const activeStatuses = <String>['accepted', 'on_the_way', 'in_progress'];
    var total = 0;

    for (final status in activeStatuses) {
      total += await _countCollection(
        'requests',
        query: requests.where('status', isEqualTo: status),
      );
    }

    return total;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> latestJobsStream({
    int limit = 6,
  }) {
    return _firestore
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> latestUsersStream({
    int limit = 6,
  }) {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}
