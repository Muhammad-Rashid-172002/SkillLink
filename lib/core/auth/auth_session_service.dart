import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skill_link/core/auth/auth_errors.dart';
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

enum AccountInitStatus { ok, needsRole, admin }

/// Response of the `initializeAccount` Cloud Function.
@immutable
class AccountInitResult {
  const AccountInitResult(this.status, this.role);

  factory AccountInitResult.fromMap(Map<String, dynamic> data) {
    final status = switch (data['status']?.toString()) {
      'ok' => AccountInitStatus.ok,
      'admin' => AccountInitStatus.admin,
      _ => AccountInitStatus.needsRole,
    };
    return AccountInitResult(status, UserRole.tryParse(data['role']));
  }

  final AccountInitStatus status;
  final UserRole? role;
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
    FirebaseFunctions? functions,
    Future<SharedPreferences> Function()? preferences,
  }) : _authOverride = auth,
       _firestoreOverride = firestore,
       _functionsOverride = functions,
       _preferences = preferences ?? SharedPreferences.getInstance;

  static final AuthSessionService instance = AuthSessionService();

  static const String _legacyRoleCachePrefix = 'skillnova.session.role.';
  static const String _pendingRoleKey = 'skillnova.session.pendingRole';

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;
  final Future<SharedPreferences> Function() _preferences;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'us-central1');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Role verified against Firestore during the last successful [resolve].
  /// Used by [RoleGate] to protect role-specific areas.
  final ValueNotifier<UserRole?> verifiedRole = ValueNotifier<UserRole?>(null);

  User? get currentUser => _auth.currentUser;

  bool _signingOut = false;

  Future<void>? _googleInit;

  /// `GoogleSignIn.initialize` must complete exactly once per process before
  /// any other Google Sign-In call; every other call waits on it otherwise.
  Future<void> ensureGoogleInitialized() {
    return _googleInit ??= GoogleSignIn.instance.initialize().catchError((
      Object error,
    ) {
      _googleInit = null; // Allow a retry on the next attempt.
      throw error;
    });
  }

  /// True while [signOut] runs, so guards don't race the logout navigation.
  bool get isSigningOut => _signingOut;

  // ---------------------------------------------------------------------------
  // Session resolution
  // ---------------------------------------------------------------------------

  /// Works out where the current person belongs.
  ///
  /// The role always comes from the server: the stored `users/{uid}.role`, or
  /// the `initializeAccount` Cloud Function for brand-new or legacy accounts.
  /// [selectedRole] is ignored for existing accounts; it is kept only so
  /// older call sites compile.
  Future<SessionSnapshot> resolve({UserRole? selectedRole}) async {
    try {
      return await _resolve();
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
        message: AuthErrors.generic,
      );
    }
  }

  Future<SessionSnapshot> _resolve() async {
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
        return SessionSnapshot.signedOut(
          message: error.code == 'user-disabled'
              ? 'This account is currently restricted. Please contact '
                    'SkillNova support so we can help.'
              : 'Your session has expired. Please sign in again.',
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

    DocumentSnapshot<Map<String, dynamic>> snapshot;
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
        message: AuthErrors.offline,
      );
    }

    var data = snapshot.data() ?? <String, dynamic>{};
    var resolution = RoleResolver.resolve(data);

    // Brand-new account whose profile was never created (app killed during
    // sign-up), or a legacy account with a missing / malformed role: ask the
    // server. It only accepts the role picked during sign-up on THIS device
    // for an account that has no role and no contrary evidence.
    if (!snapshot.exists || resolution.needsRepair || !resolution.isResolved) {
      final pending = await _pendingRoleFor(user.uid);
      final AccountInitResult result;
      try {
        result = await initializeAccount(role: pending);
      } on SessionException catch (error) {
        return SessionSnapshot(
          stage: SessionStage.error,
          message: error.message,
        );
      }
      if (result.status == AccountInitStatus.admin) {
        await signOut();
        return const SessionSnapshot(
          stage: SessionStage.restricted,
          role: UserRole.admin,
          message:
              'Admin accounts sign in through the SkillNova Admin console, '
              'not the mobile app.',
        );
      }
      if (result.status == AccountInitStatus.needsRole) {
        verifiedRole.value = null;
        return SessionSnapshot(stage: SessionStage.roleRequired, data: data);
      }
      snapshot = await _userDoc(user.uid).get();
      data = snapshot.data() ?? data;
      resolution = RoleResolver.resolve(data);
      if (!resolution.isResolved) {
        verifiedRole.value = null;
        return SessionSnapshot(stage: SessionStage.roleRequired, data: data);
      }
    }

    final role = resolution.role!;

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

    await _clearPendingRole();
    verifiedRole.value = role;

    if (!user.emailVerified) {
      return SessionSnapshot(
        stage: SessionStage.emailVerification,
        role: role,
        data: data,
      );
    }

    if (data['emailVerified'] != true) {
      final verifiedUser = user;
      unawaited(
        _refreshThenMerge(verifiedUser, {
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    }

    // The phone is verified only if Firebase Auth itself holds the number
    // (it is linked after a real SMS code check).
    if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
      return SessionSnapshot(
        stage: SessionStage.phoneVerification,
        role: role,
        data: data,
      );
    }
    if (data['phoneVerified'] != true) {
      unawaited(
        _refreshThenMerge(user, {
          'phoneNumber': user.phoneNumber,
          'phone': user.phoneNumber,
          'phoneVerified': true,
          'phoneVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }),
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

  /// Persists a role chosen on the recovery screen. The server accepts it
  /// only for an account that has no role and no contrary evidence; it can
  /// never change a valid role.
  Future<void> assignMissingRole(UserRole role) async {
    if (_auth.currentUser == null) {
      throw const SessionException('Please sign in again to continue.');
    }
    if (!role.isAppRole) {
      throw const SessionException('Choose Customer or Worker to continue.');
    }
    final result = await initializeAccount(role: role);
    switch (result.status) {
      case AccountInitStatus.ok:
        if (result.role != null && result.role != role) {
          throw SessionException(
            'This account is already registered as a ${result.role!.label}.',
          );
        }
      case AccountInitStatus.needsRole:
        throw const SessionException(
          'We couldn’t confirm this account type automatically. Please '
          'contact SkillNova support so we can fix it for you.',
        );
      case AccountInitStatus.admin:
        throw const SessionException(
          'Admin accounts sign in through the SkillNova Admin console.',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Account creation
  // ---------------------------------------------------------------------------

  /// Remembers the role chosen for sign-up before the auth account exists, so
  /// that an interrupted sign-up can be finished. It is only ever sent to the
  /// server, which ignores it for accounts that already have a role.
  Future<void> rememberPendingRole(UserRole role) async {
    try {
      final prefs = await _preferences();
      await prefs.setString(_pendingRoleKey, role.value);
    } catch (error) {
      debugPrint('Pending role cache failed: $error');
    }
  }

  /// Creates `users/{uid}` for a new account through the server.
  Future<void> createProfile({
    required User user,
    required UserRole role,
    String? name,
    String authProvider = 'password',
  }) async {
    await rememberPendingRole(role);
    final result = await initializeAccount(role: role, name: name);
    if (result.status != AccountInitStatus.ok) {
      throw const SessionException(
        'We couldn’t finish creating your account. Please try again.',
      );
    }
  }

  /// Calls the `initializeAccount` Cloud Function, which is the only place a
  /// role is ever written. Refreshes the ID token when the role claim changed
  /// so security rules see it immediately.
  Future<AccountInitResult> initializeAccount({
    UserRole? role,
    String? name,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const SessionException('Please sign in again to continue.');
    }
    try {
      final response = await _functions
          .httpsCallable('initializeAccount')
          .call(<String, dynamic>{
            if (role != null && role.isAppRole) 'role': role.value,
            if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          })
          .timeout(const Duration(seconds: 25));
      final data = Map<String, dynamic>.from(response.data as Map);
      final result = AccountInitResult.fromMap(data);
      if (result.status == AccountInitStatus.ok) {
        // Always refresh: the role claim must be on the token before any
        // role-protected read or write.
        await user.getIdToken(true);
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      // 'not-found' / 'internal' here almost always means the
      // initializeAccount function is not deployed to the Firebase project
      // the app is configured for (see docs/AUTH_SETUP.md).
      debugPrint(
        'initializeAccount failed: ${error.code} '
        '(project: ${_auth.app.options.projectId})',
      );
      throw SessionException(AuthErrors.forFunctionsCode(error.code));
    } on TimeoutException {
      throw const SessionException(AuthErrors.offline);
    }
  }

  // ---------------------------------------------------------------------------
  // Password
  // ---------------------------------------------------------------------------

  /// Sends a password reset link: the branded email via Cloud Functions when
  /// available, otherwise Firebase's built-in email. Used by "Forgot
  /// password" and by Settings > Security.
  Future<void> sendPasswordReset(String email) async {
    final address = email.trim().toLowerCase();
    try {
      await _functions
          .httpsCallable('sendCustomPasswordResetEmail')
          .call(<String, dynamic>{'email': address})
          .timeout(const Duration(seconds: 20));
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'invalid-argument') rethrow;
      await _auth.sendPasswordResetEmail(email: address);
    } on TimeoutException {
      await _auth.sendPasswordResetEmail(email: address);
    }
  }

  /// True when the signed-in account has an email/password credential.
  bool get hasPasswordSignIn {
    try {
      return _auth.currentUser?.providerData.any(
            (info) => info.providerId == 'password',
          ) ??
          false;
    } catch (_) {
      return false; // Firebase not initialised (e.g. widget tests).
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
    // Only Google accounts need a Google sign-out. Calling it for email
    // accounts (where GoogleSignIn was never initialised in this process)
    // never completes, which used to leave logout spinning forever.
    final usedGoogle =
        user?.providerData.any((info) => info.providerId == 'google.com') ??
        false;
    if (usedGoogle) {
      try {
        await ensureGoogleInitialized().timeout(const Duration(seconds: 5));
        await GoogleSignIn.instance.signOut().timeout(
          const Duration(seconds: 5),
        );
      } catch (error) {
        debugPrint('Google sign-out skipped: $error');
      }
    }
    await _auth.signOut();
    verifiedRole.value = null;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// The role picked during sign-up on this device, if the sign-up has not
  /// finished yet. Only ever forwarded to the server.
  Future<UserRole?> _pendingRoleFor(String uid) async {
    try {
      final prefs = await _preferences();
      return UserRole.tryParse(prefs.getString(_pendingRoleKey));
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPendingRole() async {
    try {
      final prefs = await _preferences();
      await prefs.remove(_pendingRoleKey);
      // Legacy per-account role cache from older builds; no longer trusted.
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_legacyRoleCachePrefix)) await prefs.remove(key);
      }
    } catch (error) {
      debugPrint('Pending role cleanup skipped: $error');
    }
  }

  /// Security rules accept `emailVerified` / `phoneVerified` only when the
  /// ID token proves them, so refresh the token before syncing the flags.
  Future<void> _refreshThenMerge(User user, Map<String, Object?> values) async {
    try {
      await user.getIdToken(true);
    } catch (error) {
      debugPrint('Token refresh skipped: $error');
    }
    await _safeMerge(user.uid, values);
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

  static String _firestoreMessage(String code) {
    debugPrint('Account load failed: $code');
    return switch (code) {
      'unavailable' || 'deadline-exceeded' => AuthErrors.offline,
      // Signed in, but the rules refused the person's own profile: the
      // project's Firestore rules are not deployed or out of date.
      'permission-denied' ||
      'not-found' ||
      'failed-precondition' => AuthErrors.serviceUnavailable,
      _ => AuthErrors.generic,
    };
  }
}
