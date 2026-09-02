import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerHomeRecord {
  const CustomerHomeRecord({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

abstract interface class CustomerHomeDataSource {
  String get userId;

  Stream<Map<String, dynamic>?> watchProfile();
  Stream<int> watchUnreadNotificationCount();
  Stream<List<CustomerHomeRecord>> watchEligibleProfessionals();
  Stream<List<CustomerHomeRecord>> watchCustomerRequests();
  Future<void> refresh();
}

class FirebaseCustomerHomeDataSource implements CustomerHomeDataSource {
  FirebaseCustomerHomeDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  String get userId => _auth.currentUser?.uid ?? '';

  Query<Map<String, dynamic>> get _eligibleProfessionalsQuery => _firestore
      .collection('users')
      .where('role', isEqualTo: 'worker')
      .where('profileCompleted', isEqualTo: true)
      .where('identityVerificationStatus', isEqualTo: 'approved')
      .where('canAcceptJobs', isEqualTo: true)
      .limit(24);

  Query<Map<String, dynamic>> get _customerRequestsQuery =>
      _firestore.collection('requests').where('customerId', isEqualTo: userId);

  @override
  Stream<Map<String, dynamic>?> watchProfile() {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Stream<int> watchUnreadNotificationCount() {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .limit(99)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Stream<List<CustomerHomeRecord>> watchEligibleProfessionals() {
    return _eligibleProfessionalsQuery.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (document) =>
                CustomerHomeRecord(id: document.id, data: document.data()),
          )
          .toList(growable: false),
    );
  }

  @override
  Stream<List<CustomerHomeRecord>> watchCustomerRequests() {
    return _customerRequestsQuery.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (document) =>
                CustomerHomeRecord(id: document.id, data: document.data()),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> refresh() async {
    await Future.wait([
      _firestore.collection('users').doc(userId).get(),
      _eligibleProfessionalsQuery.get(),
      _customerRequestsQuery.get(),
    ]);
  }
}
