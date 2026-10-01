import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skill_link/core/auth/role_resolver.dart';
import 'package:skill_link/core/auth/user_role.dart';

/// Where a signed-in (or signed-out) person must be sent next.
enum SessionStage {
  signedOut,
  emailVerification,
  phoneVerification,
  profileSetup,
  workerVerification,
  home,

  /// Account exists but no trustworthy role could be recovered. The person is
  /// asked once to choose, and the choice is persisted.
  roleRequired,

  /// Suspended, blocked, or an admin account on the mobile app.
  restricted,

  /// Network / database failure. The UI offers retry instead of logging out.
  error,
}

@immutable
class SessionSnapshot {
  const SessionSnapshot({
    required this.stage,
    this.role,
    this.message,
    this.data = const <String, dynamic>{},
  });

  const SessionSnapshot.signedOut({this.message})
    : stage = SessionStage.signedOut,
      role = null,
      data = const <String, dynamic>{};

  final SessionStage stage;
  final UserRole? role;

  /// User-safe explanation for [SessionStage.restricted] / [SessionStage.error].
  final String? message;
  final Map<String, dynamic> data;

  @override
  String toString() => 'SessionSnapshot($stage, ${role?.value})';
}

/// Thrown with a message that is safe to show to people.
class SessionException implements Exception {
  const SessionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Single source of truth for authentication state and the account role.
///
/// Every entry point (splash/session restore, email login, Google sign-in,
/// sign-up, verification steps, profile setup, logout) goes through this
/// service, so role handling lives in exactly one place.
class AuthSessionService {
  AuthSessionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Future<SharedPreferences> Function()? preferences,
  }) : _authOverride = auth,
       _firestoreOverride = firestore,
       _preferences = preferences ?? SharedPreferences.getInstance;

  static final AuthSessionService instance = AuthSessionService();

  static const String _roleCachePrefix = 'skillnova.session.role.';
  static const String _pendingRoleKey = 'skillnova.session.pendingRole';

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final Future<SharedPreferences> Function() _preferences;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Role verified against Firestore during the last successful [resolve].
  /// Used by [RoleGate] to protect role-specific areas.
  final ValueNotifier<UserRole?> verifiedRole = ValueNotifier<UserRole?>(null);

  User? get currentUser => _auth.currentUser;

  bool _signingOut = false;

  /// True while [signOut] runs, so guards don't race the logout navigation.
  bool get isSigningOut => _signingOut;

  // ---------------------------------------------------------------------------
  // Session resolution
  // ---------------------------------------------------------------------------

  /// Works out where the current person belongs.
  ///
  /// [selectedRole] is the role picked on the role-selection screen. It is only
  /// used to *recover* accounts whose stored role is missing; it never
  /// overrides a valid stored role.
  Future<SessionSnapshot> resolve({UserRole? selectedRole}) async {
    try {
      return await _resolve(selectedRole);
    } on FirebaseException catch (error) {
      debugPrint('Session resolve failed: ${error.code}');
      return SessionSnapshot(
        stage: SessionStage.error,
        message: _firestoreMessage(error.code),
      );
    } catch (error) {
      debugPrint('Session resolve failed: $error');
      return const SessionSnapshot(
        stage: SessionStage.error,
        message: 'Something went wrong while loading your account.',
      );
    }
  }

  Future<SessionSnapshot> _resolve(UserRole? selectedRole) async {
    var user = _auth.currentUser;
    if (user == null) {
      verifiedRole.value = null;
      return const SessionSnapshot.signedOut();
    }

    try {
      await user.reload().timeout(const Duration(seconds: 12));
      user = _auth.currentUser;
    } on FirebaseAuthException catch (error) {
      if (_isDeadSession(error.code)) {
        await signOut(clearDeviceToken: false);
        return const SessionSnapshot.signedOut(
          message: 'Your session has expired. Please sign in again.',
        );
      }
      // Offline or transient: continue with the cached user.
      debugPrint('Session reload skipped: ${error.code}');
    } on TimeoutException {
      debugPrint('Session reload timed out; using cached user.');
    }

    if (user == null) {
      verifiedRole.value = null;
      return const SessionSnapshot.signedOut();
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _userDoc(
        user.uid,
      ).get().timeout(const Duration(seconds: 15));
    } on FirebaseException catch (error) {
      return SessionSnapshot(
        stage: SessionStage.error,
        message: _firestoreMessage(error.code),
      );
    } on TimeoutException {
      return const SessionSnapshot(
        stage: SessionStage.error,
        message:
            'We could not reach SkillNova. Check your connection and try again.',
      );
    }

    final cachedRole = await _cachedRole(user.uid);
    var data = snapshot.data() ?? <String, dynamic>{};

    final resolution = RoleResolver.resolve(
      data,
      cachedRole: cachedRole,
      selectedRole: selectedRole,
    );

    if (!resolution.isResolved) {
      verifiedRole.value = null;
      return SessionSnapshot(stage: SessionStage.roleRequired, data: data);
    }

    final role = resolution.role!;

    if (!snapshot.exists) {
      // Auth account exists but the profile write never landed (e.g. app was
      // killed or offline during sign-up). Recreate it instead of failing.
      await _writeInitialProfile(user, role, recovered: true);
      data = (await _userDoc(user.uid).get()).data() ?? data;
    } else if (resolution.needsPersist) {
      await _repairRole(user.uid, role, resolution.source);
      data = {...data, 'role': role.value};
    }

    if (role == UserRole.admin) {
      await signOut();
      return const SessionSnapshot(
        stage: SessionStage.restricted,
        role: UserRole.admin,
        message:
            'Admin accounts sign in through the SkillNova Admin console, '
            'not the mobile app.',
      );
    }

    final status = data['accountStatus']?.toString().trim().toLowerCase();
    if (status == 'suspended' || status == 'blocked' || status == 'deleted') {
      await signOut();
      return SessionSnapshot(
        stage: SessionStage.restricted,
        role: role,
        message:
            'This account is currently restricted. Please contact SkillNova '
            'support so we can help.',
      );
    }

    await _rememberRole(user.uid, role);
    verifiedRole.value = role;

    if (!user.emailVerified) {
      return SessionSnapshot(
        stage: SessionStage.emailVerification,
        role: role,
        data: data,
      );
    }

    if (data['emailVerified'] != true) {
      unawaited(
        _safeMerge(user.uid, {
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    }

    if (data['phoneVerified'] != true || user.phoneNumber == null) {
      return SessionSnapshot(
        stage: SessionStage.phoneVerification,
        role: role,
        data: data,
      );
    }

    if (data['profileCompleted'] != true) {
      return SessionSnapshot(
        stage: SessionStage.profileSetup,
        role: role,
        data: data,
      );
    }

    if (role == UserRole.worker &&
        data['identityVerificationStatus']?.toString() != 'approved') {
      return SessionSnapshot(
        stage: SessionStage.workerVerification,
        role: role,
        data: data,
      );
    }

    return SessionSnapshot(stage: SessionStage.home, role: role, data: data);
  }

  /// Persists a role chosen on the recovery screen. Never changes a role that
  /// is already valid.
  Future<void> assignMissingRole(UserRole role) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const SessionException('Please sign in again to continue.');
    }
    if (!role.isAppRole) {
      throw const SessionException('Choose Customer or Worker to continue.');
    }
    final reference = _userDoc(user.uid);
    final snapshot = await reference.get();
    if (!snapshot.exists) {
      await _writeInitialProfile(user, role, recovered: true);
    } else {
      final existing = UserRole.tryParse(snapshot.data()?['role']);
      if (existing != null && existing != role) {
        throw SessionException(
          'This account is already registered as a ${existing.label}.',
        );
      }
      await _repairRole(user.uid, role, RoleSource.userSelection);
    }
    await _rememberRole(user.uid, role);
  }

  // ---------------------------------------------------------------------------
  // Account creation
  // ---------------------------------------------------------------------------

  /// Remembers the role chosen for sign-up before the auth account exists, so
  /// that an interrupted sign-up can still be recovered correctly.
  Future<void> rememberPendingRole(UserRole role) async {
    try {
      final prefs = await _preferences();
      await prefs.setString(_pendingRoleKey, role.value);
    } catch (error) {
      debugPrint('Pending role cache failed: $error');
    }
  }

  /// Creates `users/{uid}` for a new account with the canonical role.
  Future<void> createProfile({
    required User user,
    required UserRole role,
    String? name,
    String authProvider = 'password',
  }) async {
    await _writeInitialProfile(
      user,
      role,
      name: name,
      authProvider: authProvider,
    );
    await _rememberRole(user.uid, role);
  }

  Future<void> _writeInitialProfile(
    User user,
    UserRole role, {
    String? name,
    String authProvider = 'password',
    bool recovered = false,
  }) async {
    final isWorker = role == UserRole.worker;
    final displayName = (name ?? user.displayName ?? '').trim();
    final emailVerified = user.emailVerified || authProvider == 'google';
    await _userDoc(user.uid).set({
      'uid': user.uid,
      'name': displayName.isEmpty ? 'SkillNova member' : displayName,
      'email': user.email,
      if (user.photoURL != null) 'photoUrl': user.photoURL,
      'role': role.value,
      'authProvider': authProvider,
      'emailVerified': emailVerified,
      if (emailVerified) 'emailVerifiedAt': FieldValue.serverTimestamp(),
      'phoneVerified': false,
      'phoneNumber': user.phoneNumber,
      'profileCompleted': false,
      'identityVerificationStatus': isWorker ? 'not_submitted' : 'not_required',
      'backgroundVerificationStatus': isWorker
          ? 'not_submitted'
          : 'not_required',
      'verificationLevel': isWorker ? 'unverified' : 'basic',
      'canAcceptJobs': false,
      'accountStatus': 'active',
      if (recovered) 'profileRecoveredAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _repairRole(String uid, UserRole role, RoleSource source) async {
    try {
      await _userDoc(uid).set({
        'role': role.value,
        'roleRecoveredFrom': source.name,
        'roleRecoveredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      // Routing still works for this session; repair is retried next launch.
      debugPrint('Role repair deferred: ${error.code}');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// Clean logout: removes this device's push token (so the account stops
  /// receiving notifications here), signs out of Firebase and Google, and
  /// clears in-memory role state.
  Future<void> signOut({bool clearDeviceToken = true}) async {
    _signingOut = true;
    try {
      await _signOut(clearDeviceToken);
    } finally {
      _signingOut = false;
    }
  }

  Future<void> _signOut(bool clearDeviceToken) async {
    final user = _auth.currentUser;
    if (user != null && clearDeviceToken) {
      try {
        await _userDoc(user.uid)
            .update({
              'fcmToken': FieldValue.delete(),
              'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 5));
      } catch (error) {
        debugPrint('Push token cleanup skipped: $error');
      }
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Not signed in with Google or plugin unavailable on this platform.
    }
    await _auth.signOut();
    verifiedRole.value = null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<UserRole?> _cachedRole(String uid) async {
    try {
      final prefs = await _preferences();
      return UserRole.tryParse(prefs.getString('$_roleCachePrefix$uid')) ??
          UserRole.tryParse(prefs.getString(_pendingRoleKey));
    } catch (_) {
      return null;
    }
  }

  Future<void> _rememberRole(String uid, UserRole role) async {
    try {
      final prefs = await _preferences();
      await prefs.setString('$_roleCachePrefix$uid', role.value);
      await prefs.remove(_pendingRoleKey);
    } catch (error) {
      debugPrint('Role cache failed: $error');
    }
  }

  Future<void> _safeMerge(String uid, Map<String, Object?> values) async {
    try {
      await _userDoc(uid).set(values, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Profile sync skipped: $error');
    }
  }

  static bool _isDeadSession(String code) => const {
    'user-token-expired',
    'user-disabled',
    'user-not-found',
    'invalid-user-token',
    'requires-recent-login',
  }.contains(code);

  static String _firestoreMessage(String code) => switch (code) {
    'unavailable' || 'deadline-exceeded' =>
      'You appear to be offline. Check your connection and try again.',
    'permission-denied' =>
      'We could not open your account right now. Please sign in again.',
    _ => 'Something went wrong while loading your account. Please try again.',
  };
}
