import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAuthService {
  AdminAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Admin ko email/password se login karta hai aur Firestore ke
  /// `admins/{uid}` document se authorization verify karta hai.
  Future<AdminProfile> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw const AdminAuthException(
          'Unable to complete login. Please try again.',
        );
      }

      return await _verifyAdmin(user);
    } on FirebaseAuthException catch (error) {
      throw AdminAuthException(_mapFirebaseAuthError(error));
    } on FirebaseException catch (error) {
      throw AdminAuthException(
        error.message ?? 'Unable to connect with Database.',
      );
    } on AdminAuthException {
      rethrow;
    } catch (_) {
      throw const AdminAuthException(
        'Something went wrong. Please try again.',
      );
    }
  }

  /// Current logged-in user ko admin ke taur par verify karta hai.
  Future<AdminProfile?> getCurrentAdmin() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      return await _verifyAdmin(user);
    } on AdminAuthException {
      await signOut();
      return null;
    }
  }

  Future<AdminProfile> _verifyAdmin(User user) async {
    final adminDocument =
        await _firestore.collection('admins').doc(user.uid).get();

    if (!adminDocument.exists) {
      await signOut();

      throw const AdminAuthException(
        'You do not have permission to access the admin panel. Please contact the super admin.',
      );
    }

    final data = adminDocument.data();

    if (data == null) {
      await signOut();

      throw const AdminAuthException(
        'Admin profile data is not available.',
      );
    }

    final isActive = data['isActive'] as bool? ?? false;

    if (!isActive) {
      await signOut();

      throw const AdminAuthException(
        'Your admin account is inactive. Please contact the super admin.',
      );
    }

    final storedEmail =
        (data['email'] as String?)?.trim().toLowerCase() ?? '';

    final authenticatedEmail = user.email?.trim().toLowerCase() ?? '';

    if (storedEmail.isNotEmpty &&
        authenticatedEmail.isNotEmpty &&
        storedEmail != authenticatedEmail) {
      await signOut();

      throw const AdminAuthException(
        'Admin email verification match nahi hui.',
      );
    }

    return AdminProfile(
      uid: user.uid,
      email: user.email ?? storedEmail,
      name: data['name'] as String? ?? 'SkillNova Admin',
      role: data['role'] as String? ?? 'admin',
      isActive: isActive,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const AdminAuthException(
        'Please enter your email address to reset your password.',
      );
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(
        email: normalizedEmail,
      );
    } on FirebaseAuthException catch (error) {
      throw AdminAuthException(_mapFirebaseAuthError(error));
    } catch (_) {
      throw const AdminAuthException(
        'Failed to send the password reset email.',
      );
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email address is not valid.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';

      case 'too-many-requests':
        return 'Too many login attempts have been made. Please try again later.';

      case 'network-request-failed':
        return 'Please check your internet connection and try again.';

      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in over database.';

      default:
        return error.message ?? 'Login could not be completed.';
    }
  }
}

class AdminProfile {
  const AdminProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final String? photoUrl;

  bool get isSuperAdmin => role == 'super_admin';
}

class AdminAuthException implements Exception {
  const AdminAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}