import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_models.dart';

abstract interface class ExploreDataSource {
  String get customerId;

  Stream<Map<String, dynamic>?> watchCustomerProfile();
  Stream<List<ExploreProfessional>> watchEligibleProfessionals();
  Future<void> refresh();
}

class FirebaseExploreDataSource implements ExploreDataSource {
  FirebaseExploreDataSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  String get customerId => _auth.currentUser?.uid ?? '';

  Query<Map<String, dynamic>> get _professionalsQuery => _firestore
      .collection('users')
      .where('role', isEqualTo: 'worker')
      .where('profileCompleted', isEqualTo: true)
      .where('identityVerificationStatus', isEqualTo: 'approved')
      .where('canAcceptJobs', isEqualTo: true)
      .limit(60);

  @override
  Stream<Map<String, dynamic>?> watchCustomerProfile() {
    return _firestore
        .collection('users')
        .doc(customerId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Stream<List<ExploreProfessional>> watchEligibleProfessionals() {
    return _professionalsQuery.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (document) =>
                ExploreProfessional(id: document.id, data: document.data()),
          )
          .where((professional) => professional.isEligible)
          .toList(growable: false),
    );
  }

  @override
  Future<void> refresh() async {
    await Future.wait([
      _firestore.collection('users').doc(customerId).get(),
      _professionalsQuery.get(),
    ]);
  }
}

abstract interface class ExploreLocationService {
  Future<SkillNovaCoordinate?> currentLocation();
}

class DeviceExploreLocationService implements ExploreLocationService {
  @override
  Future<SkillNovaCoordinate?> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return SkillNovaCoordinate(position.latitude, position.longitude);
  }
}
