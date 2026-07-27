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
          'Login complete nahi ho saka. Dobara try karein.',
        );
      }

      return await _verifyAdmin(user);
    } on FirebaseAuthException catch (error) {
      throw AdminAuthException(_mapFirebaseAuthError(error));
    } on FirebaseException catch (error) {
      throw AdminAuthException(
        error.message ?? 'Firebase se connect nahi ho saka.',
      );
    } on AdminAuthException {
      rethrow;
    } catch (_) {
      throw const AdminAuthException(
        'Kuch ghalat ho gaya. Dobara try karein.',
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
        'Aapko admin panel access karne ki permission nahi hai.',
      );
    }

    final data = adminDocument.data();

    if (data == null) {
      await signOut();

      throw const AdminAuthException(
        'Admin profile ka data available nahi hai.',
      );
    }

    final isActive = data['isActive'] as bool? ?? false;

    if (!isActive) {
      await signOut();

      throw const AdminAuthException(
        'Aapka admin account inactive hai. Super admin se contact karein.',
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
      name: data['name'] as String? ?? 'SkillLink Admin',
      role: data['role'] as String? ?? 'admin',
      isActive: isActive,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const AdminAuthException(
        'Password reset ke liye email enter karein.',
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
        'Password reset email send nahi ho saki.',
      );
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email address valid nahi hai.';

      case 'user-disabled':
        return 'Ye account disable kar diya gaya hai.';

      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ya password ghalat hai.';

      case 'too-many-requests':
        return 'Bohat zyada login attempts hue hain. Thori dair baad try karein.';

      case 'network-request-failed':
        return 'Internet connection check karein aur dobara try karein.';

      case 'operation-not-allowed':
        return 'Firebase mein Email/Password login enable nahi hai.';

      default:
        return error.message ?? 'Login complete nahi ho saka.';
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