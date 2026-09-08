import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';

import 'worker_profile_models.dart';

class WorkerProfileException implements Exception {
  const WorkerProfileException(this.message);
  final String message;
}

abstract interface class WorkerProfileRepository {
  WorkerIdentity? get currentIdentity;
  Stream<WorkerProfile> watchProfile();
  Future<WorkerProfile> loadProfile();
  Future<void> updateProfile(WorkerProfileUpdate update);
  Future<String> uploadProfilePhoto(
    String path, {
    ValueChanged<double>? onProgress,
  });
  Future<void> setAcceptingJobs(bool accepting);
  Future<void> signOut();
}

class FirebaseWorkerProfileRepository implements WorkerProfileRepository {
  FirebaseWorkerProfileRepository({
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
    if (user == null) {
      throw const WorkerProfileException('Please sign in again.');
    }
    return user;
  }

  @override
  WorkerIdentity? get currentIdentity {
    final user = _auth.currentUser;
    if (user == null) return null;
    return WorkerIdentity(
      uid: user.uid,
      authDisplayName: user.displayName?.trim() ?? '',
      email: user.email?.trim() ?? '',
      emailVerified: user.emailVerified,
      phone: user.phoneNumber?.trim() ?? '',
      createdAt: user.metadata.creationTime,
    );
  }

  @override
  Stream<WorkerProfile> watchProfile() {
    final identity = currentIdentity;
    if (identity == null) {
      return Stream<WorkerProfile>.error(
        const WorkerProfileException('Please sign in again.'),
      );
    }
    return _firestore
        .collection('users')
        .doc(identity.uid)
        .snapshots()
        .map(
          (snapshot) => WorkerProfile(
            identity: currentIdentity ?? identity,
            data: snapshot.data() ?? const <String, dynamic>{},
          ),
        );
  }

  @override
  Future<WorkerProfile> loadProfile() async {
    final identity = currentIdentity;
    if (identity == null) {
      throw const WorkerProfileException('Please sign in again.');
    }
    final snapshot = await _firestore
        .collection('users')
        .doc(identity.uid)
        .get();
    return WorkerProfile(
      identity: identity,
      data: snapshot.data() ?? const <String, dynamic>{},
    );
  }

  @override
  Future<void> updateProfile(WorkerProfileUpdate update) async {
    final user = _user;
    if (update.name.trim().length < 3) {
      throw const WorkerProfileException('Enter a valid display name.');
    }
    if (!allServices.any((service) => service.title == update.skill)) {
      throw const WorkerProfileException('Choose a supported primary service.');
    }
    if (validateWorkerRate(update.hourlyRate) != null) {
      throw const WorkerProfileException('Enter a valid service rate.');
    }
    if (update.experience.trim().isEmpty || update.serviceArea.isEmpty) {
      throw const WorkerProfileException(
        'Experience and service area are required.',
      );
    }
    final name = update.name.trim();
    final photo = update.photoUrl.trim();
    await user.updateDisplayName(name);
    if (photo.isNotEmpty && photo != user.photoURL) {
      await user.updatePhotoURL(photo);
    }
    await _firestore.collection('users').doc(user.uid).set({
      'name': name,
      'skill': update.skill,
      'experience': update.experience.trim(),
      'hourlyRate': normalizedWorkerRate(update.hourlyRate),
      'city': update.city.trim(),
      'area': update.area.trim(),
      'location': update.serviceArea,
      'bio': update.bio.trim(),
      'profileImageUrl': photo,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<String> uploadProfilePhoto(
    String path, {
    ValueChanged<double>? onProgress,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const WorkerProfileException('The selected photo is unavailable.');
    }
    if (await file.length() > 5 * 1024 * 1024) {
      throw const WorkerProfileException('Choose a photo smaller than 5 MB.');
    }
    final extension = _validatedExtension(path);
    final reference = _storage.ref(
      'profile_images/workers/${_user.uid}/profile.$extension',
    );
    final task = reference.putFile(
      file,
      SettableMetadata(
        contentType: _contentType(extension),
        customMetadata: const {'type': 'worker_profile'},
      ),
    );
    if (onProgress != null) {
      task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes <= 0) return;
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      });
    }
    final snapshot = await task;
    return snapshot.ref.getDownloadURL();
  }

  String _validatedExtension(String path) {
    final parts = path.split('.');
    final extension = parts.length > 1 ? parts.last.toLowerCase() : '';
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw const WorkerProfileException(
        'Choose a JPG, PNG, or WebP profile photo.',
      );
    }
    return extension;
  }

  String _contentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  @override
  Future<void> setAcceptingJobs(bool accepting) async {
    final user = _user;
    final reference = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) {
        throw const WorkerProfileException('Worker profile was not found.');
      }
      if (accepting) {
        final blocker = WorkerEligibilityAdapter.availabilityBlocker(
          WorkerHomeProfile(uid: user.uid, data: data),
        );
        if (blocker != null) throw WorkerProfileException(blocker.message);
      }
      transaction.update(reference, {
        'canAcceptJobs': accepting,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

abstract interface class WorkerProfileImagePicker {
  Future<String?> pick(ImageSource source);
}

class DeviceWorkerProfileImagePicker implements WorkerProfileImagePicker {
  DeviceWorkerProfileImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return null;
    if (await File(image.path).length() > 5 * 1024 * 1024) {
      throw const WorkerProfileException('Choose a photo smaller than 5 MB.');
    }
    final parts = image.path.split('.');
    final extension = parts.length > 1 ? parts.last.toLowerCase() : '';
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw const WorkerProfileException(
        'Choose a JPG, PNG, or WebP profile photo.',
      );
    }
    return image.path;
  }
}
