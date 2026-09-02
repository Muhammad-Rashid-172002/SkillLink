import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_models.dart';

abstract interface class CustomerProfileRepository {
  CustomerIdentity? get currentIdentity;
  Stream<CustomerProfile> watchProfile();
  Future<CustomerProfile> loadProfile();
  Future<void> updateProfile(CustomerProfileUpdate update);
  Future<String> uploadProfilePhoto(String path);
  Future<void> signOut();
}

class FirebaseCustomerProfileRepository implements CustomerProfileRepository {
  FirebaseCustomerProfileRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    return user;
  }

  @override
  CustomerIdentity? get currentIdentity {
    final user = _auth.currentUser;
    if (user == null) return null;
    return CustomerIdentity(
      uid: user.uid,
      authDisplayName: user.displayName?.trim() ?? '',
      email: user.email?.trim() ?? '',
      emailVerified: user.emailVerified,
      phone: user.phoneNumber?.trim() ?? '',
      createdAt: user.metadata.creationTime,
    );
  }

  @override
  Stream<CustomerProfile> watchProfile() {
    final identity = currentIdentity;
    if (identity == null) return Stream<CustomerProfile>.error('Signed out');
    return _firestore
        .collection('users')
        .doc(identity.uid)
        .snapshots()
        .map(
          (snapshot) => CustomerProfile.from(
            identity: currentIdentity ?? identity,
            data: snapshot.data() ?? const <String, dynamic>{},
          ),
        );
  }

  @override
  Future<CustomerProfile> loadProfile() async {
    final identity = currentIdentity;
    if (identity == null) throw StateError('Please sign in again.');
    final snapshot = await _firestore
        .collection('users')
        .doc(identity.uid)
        .get();
    return CustomerProfile.from(
      identity: identity,
      data: snapshot.data() ?? const <String, dynamic>{},
    );
  }

  @override
  Future<void> updateProfile(CustomerProfileUpdate update) async {
    final user = _user;
    await user.updateDisplayName(update.name);
    await _firestore.collection('users').doc(user.uid).set({
      'name': update.name,
      'city': update.city,
      'area': update.area,
      'address': update.address,
      'bio': update.bio,
      'profileImage': update.photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<String> uploadProfilePhoto(String path) async {
    final reference = _storage.ref('customer_profiles/${_user.uid}.jpg');
    await reference.putFile(File(path));
    return reference.getDownloadURL();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

abstract interface class CustomerProfileImagePicker {
  Future<String?> pick(ImageSource source);
}

class DeviceCustomerProfileImagePicker implements CustomerProfileImagePicker {
  DeviceCustomerProfileImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return null;
    if (await File(image.path).length() > 5 * 1024 * 1024) {
      throw const FormatException('Please choose an image smaller than 5 MB.');
    }
    return image.path;
  }
}
