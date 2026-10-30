import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skilllink_admin/services/verification_management_service.dart';

// ---------------------------------------------------------------------------
// User Management for the admin console.
//
// Reading the user list uses Firestore (admins may read users/*). Everything
// that changes an account — suspension and permanent deletion — goes through
// callable Cloud Functions that check admin rights on the server
// (`adminSetAccountStatus`, `adminDeleteUser`, `adminDeleteUsers`).
// Verification approval reuses the existing verification workflow.
// ---------------------------------------------------------------------------

/// Verification state shown in the console. A user is only "verified" when
/// the platform verified them — never because the account exists, and never
/// from legacy client-writable flags such as `isVerified`.
enum UserVerification { verified, unverified, pending, rejected }

/// Filters offered on the User Management screen.
enum UserListFilter {
  all('All Users'),
  verified('Verified'),
  unverified('Unverified'),
  pending('Pending Verification'),
  rejected('Rejected'),
  suspended('Suspended'),
  incomplete('Incomplete Profiles');

  const UserListFilter(this.label);
  final String label;
}

enum UserTypeFilter {
  all('All types'),
  customers('Customers'),
  workers('Workers');

  const UserTypeFilter(this.label);
  final String label;
}

enum UserSort {
  newest('Newest first'),
  oldest('Oldest first');

  const UserSort(this.label);
  final String label;
}

/// Reasons accepted by `adminDeleteUser` (keys must match the backend).
enum DeletionReason {
  fakeAccount('fake_account', 'Fake Account'),
  invalidInformation('invalid_information', 'Invalid Information'),
  failedVerification('failed_verification', 'Failed Verification'),
  duplicateAccount('duplicate_account', 'Duplicate Account'),
  spamAbuse('spam_abuse', 'Spam or Abuse'),
  policyViolation('policy_violation', 'Policy Violation'),
  other('other', 'Other');

  const DeletionReason(this.key, this.label);
  final String key;
  final String label;
}

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.accountStatus,
    required this.emailVerified,
    required this.phoneVerified,
    required this.identityStatus,
    required this.profileCompleted,
    required this.createdAt,
    required this.photoUrl,
    required this.rawData,
  });

  final String id;
  final String name;

  /// Empty when unknown.
  final String email;

  /// Empty when unknown.
  final String phone;
  final String role;
  final String accountStatus;
  final bool emailVerified;
  final bool phoneVerified;

  /// Worker identity (CNIC) review state, e.g. not_submitted, pending,
  /// approved, rejected, more_information_required. Customers: not_required.
  final String identityStatus;
  final bool profileCompleted;
  final DateTime? createdAt;
  final String? photoUrl;
  final Map<String, dynamic> rawData;

  bool get isWorker => role == 'worker';
  bool get isCustomer => role == 'customer';
  bool get isSuspended =>
      const {'suspended', 'blocked', 'deleted'}.contains(accountStatus);

  String get displayName => name.isEmpty ? 'Unnamed user' : name;

  String get roleLabel => switch (role) {
    'worker' => 'Worker',
    'customer' => 'Customer',
    _ => 'Unknown',
  };

  String get accountStatusLabel => switch (accountStatus) {
    'suspended' || 'blocked' => 'Suspended',
    'deleted' => 'Deleting',
    _ => 'Active',
  };

  String get identityStatusLabel => switch (identityStatus) {
    'approved' => 'Approved',
    'pending' || 'submitted' || 'in_review' => 'Pending review',
    'rejected' => 'Rejected',
    'more_information_required' => 'More info needed',
    'not_required' || '' => 'Not required',
    _ => 'Not submitted',
  };

  UserVerification get verification {
    if (isWorker) {
      return switch (identityStatus) {
        'approved' => UserVerification.verified,
        'pending' || 'submitted' || 'in_review' => UserVerification.pending,
        'rejected' => UserVerification.rejected,
        _ => UserVerification.unverified,
      };
    }
    // Customers have no identity review: verified means the platform
    // confirmed both their email and their phone number.
    return emailVerified && phoneVerified
        ? UserVerification.verified
        : UserVerification.unverified;
  }

  /// What is still missing from the profile, in plain words.
  List<String> get missingProfileItems => [
    if (name.isEmpty || name == 'SkillNova member') 'Name',
    if (email.isEmpty) 'Email',
    if (phone.isEmpty) 'Phone number',
    if (!emailVerified) 'Email verification',
    if (!phoneVerified) 'Phone verification',
    if (!profileCompleted) 'Profile setup',
    if (isWorker && identityStatus != 'approved') 'Identity verification',
  ];

  /// Phone with only the first 3 and last 3 characters visible.
  String get maskedPhone => maskPhone(phone);

  factory ManagedUser.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => ManagedUser.fromMap(document.id, document.data() ?? const {});

  factory ManagedUser.fromMap(String id, Map<String, dynamic> data) {
    String text(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    bool flag(String key) => data[key] == true;

    DateTime? date(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
      }
      return null;
    }

    final role = text(['role']).toLowerCase();
    var status = text(['accountStatus']).toLowerCase();
    if (status.isEmpty && (flag('isBlocked') || flag('blocked'))) {
      status = 'blocked';
    }
    var identity = text(['identityVerificationStatus']).toLowerCase();
    if (identity.isEmpty) identity = role == 'worker' ? 'not_submitted' : '';
    final photo = text(['photoUrl', 'profileImage', 'imageUrl']);
    return ManagedUser(
      id: id,
      name: text(['name', 'fullName', 'displayName']),
      email: text(['email']),
      phone: text(['phoneNumber', 'phone', 'mobile']),
      role: role == 'worker' || role == 'customer' ? role : 'unknown',
      accountStatus: status.isEmpty ? 'active' : status,
      emailVerified: flag('emailVerified'),
      phoneVerified: flag('phoneVerified'),
      identityStatus: identity,
      profileCompleted: flag('profileCompleted'),
      createdAt: date(['createdAt', 'joinedAt', 'registeredAt']),
      photoUrl: photo.isEmpty ? null : photo,
      rawData: data,
    );
  }
}

String maskPhone(String phone) {
  final value = phone.replaceAll(RegExp(r'\s'), '');
  if (value.isEmpty) return '';
  if (value.length < 7) return '•••';
  return '${value.substring(0, 3)}${'•' * (value.length - 6)}'
      '${value.substring(value.length - 3)}';
}

// ------------------------------------------------------------- list logic

/// Filter, search and sort used by the screen; pure for testing.
class UserQuery {
  const UserQuery({
    this.filter = UserListFilter.all,
    this.type = UserTypeFilter.all,
    this.search = '',
    this.sort = UserSort.newest,
  });

  final UserListFilter filter;
  final UserTypeFilter type;
  final String search;
  final UserSort sort;

  static bool matchesFilter(
    ManagedUser user,
    UserListFilter filter,
  ) => switch (filter) {
    UserListFilter.all => true,
    UserListFilter.verified => user.verification == UserVerification.verified,
    UserListFilter.unverified =>
      user.verification == UserVerification.unverified,
    UserListFilter.pending => user.verification == UserVerification.pending,
    UserListFilter.rejected => user.verification == UserVerification.rejected,
    UserListFilter.suspended => user.isSuspended,
    UserListFilter.incomplete => !user.profileCompleted,
  };

  bool matches(ManagedUser user) {
    final typeOk = switch (type) {
      UserTypeFilter.all => true,
      UserTypeFilter.customers => user.isCustomer,
      UserTypeFilter.workers => user.isWorker,
    };
    if (!typeOk || !matchesFilter(user, filter)) return false;
    final query = search.trim().toLowerCase();
    if (query.isEmpty) return true;
    final digits = query.replaceAll(RegExp(r'[^0-9]'), '');
    final phoneDigits = user.phone.replaceAll(RegExp(r'[^0-9]'), '');
    // "0300…" (local) also matches "+92300…" (stored international form).
    final phoneMatch =
        digits.length >= 3 &&
        (phoneDigits.contains(digits) ||
            (digits.startsWith('0') &&
                phoneDigits.contains(digits.substring(1))));
    return user.name.toLowerCase().contains(query) ||
        user.email.toLowerCase().contains(query) ||
        user.id.toLowerCase().contains(query) ||
        phoneMatch;
  }

  List<ManagedUser> apply(Iterable<ManagedUser> users) {
    final result = users.where(matches).toList();
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    result.sort((a, b) {
      final compare = (a.createdAt ?? epoch).compareTo(b.createdAt ?? epoch);
      return sort == UserSort.newest ? -compare : compare;
    });
    return result;
  }
}

class UserStats {
  const UserStats({
    required this.total,
    required this.verified,
    required this.unverified,
    required this.pending,
    required this.rejected,
    required this.suspended,
    required this.incomplete,
    required this.recent,
  });

  final int total;
  final int verified;
  final int unverified;
  final int pending;
  final int rejected;
  final int suspended;
  final int incomplete;

  /// Registered in the last [recentWindow].
  final int recent;

  static const Duration recentWindow = Duration(days: 7);

  factory UserStats.of(List<ManagedUser> users, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    int count(UserListFilter filter) =>
        users.where((u) => UserQuery.matchesFilter(u, filter)).length;
    return UserStats(
      total: users.length,
      verified: count(UserListFilter.verified),
      unverified: count(UserListFilter.unverified),
      pending: count(UserListFilter.pending),
      rejected: count(UserListFilter.rejected),
      suspended: count(UserListFilter.suspended),
      incomplete: count(UserListFilter.incomplete),
      recent: users
          .where(
            (u) =>
                u.createdAt != null &&
                clock.difference(u.createdAt!) <= recentWindow,
          )
          .length,
    );
  }
}

// ----------------------------------------------------------- operations

class DeletionOutcome {
  const DeletionOutcome({
    required this.uid,
    required this.status,
    this.failedSteps = const [],
    this.message,
    this.requestId,
  });

  final String uid;

  /// completed | already_deleted | partial_failure | failed
  final String status;
  final List<String> failedSteps;
  final String? message;
  final String? requestId;

  bool get succeeded => status == 'completed' || status == 'already_deleted';

  String get description => switch (status) {
    'completed' => 'Deleted',
    'already_deleted' => 'Already deleted',
    'partial_failure' =>
      'Partly deleted — retry to finish (${failedSteps.join(', ')})',
    _ => message ?? 'Could not be deleted',
  };
}

class BulkDeletionOutcome {
  const BulkDeletionOutcome(this.results);
  final List<DeletionOutcome> results;
  int get succeeded => results.where((r) => r.succeeded).length;
  int get failed => results.length - succeeded;
}

class VerificationDetails {
  const VerificationDetails({required this.request});
  final VerificationRequestModel request;
}

/// Everything the User Management screens need. The Firebase
/// implementation is below; tests use a fake.
abstract class UserAdminGateway {
  String? get currentAdminUid;
  Stream<List<ManagedUser>> watchUsers();
  Future<void> setAccountStatus(
    String uid, {
    required bool suspended,
    String reason = '',
  });
  Future<DeletionOutcome> deleteUser(
    String uid, {
    required DeletionReason reason,
    String detail = '',
  });

  /// Deletes up to [UserManagementService.maxBulkPerCall] accounts per call.
  Future<BulkDeletionOutcome> deleteUsers(
    List<String> uids, {
    required DeletionReason reason,
    String detail = '',
    Map<String, DeletionReason> perUserReasons = const {},
  });
  Future<VerificationDetails?> loadVerification(String uid);
  Future<String?> documentUrl(String storagePath);
  Future<void> approveVerification(VerificationRequestModel request);
  Future<void> rejectVerification(
    VerificationRequestModel request,
    String reason,
  );
}

class UserManagementService implements UserAdminGateway {
  UserManagementService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    VerificationManagementService? verification,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functionsOverride = functions,
       _auth = auth ?? FirebaseAuth.instance,
       _verificationOverride = verification;

  /// Must not exceed MAX_BULK_DELETE in functions/account_deletion.js.
  static const int maxBulkPerCall = 10;

  /// Largest selection the console sends in one bulk run.
  static const int maxBulkSelection = 50;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functionsOverride;
  final FirebaseAuth _auth;
  final VerificationManagementService? _verificationOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'us-central1');
  VerificationManagementService get _verification =>
      _verificationOverride ?? VerificationManagementService();

  @override
  String? get currentAdminUid => _auth.currentUser?.uid;

  @override
  Stream<List<ManagedUser>> watchUsers() => _firestore
      .collection('users')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            // Console admins are managed elsewhere, not as app users.
            .where((doc) => doc.data()['role'] != 'admin')
            .map(ManagedUser.fromDocument)
            .toList(),
      );

  @override
  Future<void> setAccountStatus(
    String uid, {
    required bool suspended,
    String reason = '',
  }) async {
    await _functions.httpsCallable('adminSetAccountStatus').call({
      'uid': uid,
      'status': suspended ? 'suspended' : 'active',
      'reason': reason.trim(),
    });
  }

  @override
  Future<DeletionOutcome> deleteUser(
    String uid, {
    required DeletionReason reason,
    String detail = '',
  }) async {
    try {
      final response = await _functions
          .httpsCallable(
            'adminDeleteUser',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
          )
          .call({'uid': uid, 'reason': reason.key, 'reasonDetail': detail});
      final data = Map<String, dynamic>.from(response.data as Map);
      return DeletionOutcome(
        uid: uid,
        status: data['status']?.toString() ?? 'failed',
        failedSteps: List<String>.from(data['failedSteps'] as List? ?? []),
        requestId: data['requestId']?.toString(),
      );
    } on FirebaseFunctionsException catch (error) {
      return DeletionOutcome(
        uid: uid,
        status: 'failed',
        message: error.message ?? 'The account could not be deleted.',
      );
    }
  }

  @override
  Future<BulkDeletionOutcome> deleteUsers(
    List<String> uids, {
    required DeletionReason reason,
    String detail = '',
    Map<String, DeletionReason> perUserReasons = const {},
  }) async {
    if (uids.length > maxBulkPerCall) {
      throw ArgumentError('At most $maxBulkPerCall accounts per call.');
    }
    try {
      final response = await _functions
          .httpsCallable(
            'adminDeleteUsers',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
          )
          .call({
            'uids': uids,
            'reason': reason.key,
            'reasonDetail': detail,
            'reasons': {
              for (final entry in perUserReasons.entries)
                entry.key: {'reason': entry.value.key},
            },
          });
      final data = Map<String, dynamic>.from(response.data as Map);
      final requestId = data['requestId']?.toString();
      final results = <DeletionOutcome>[];
      for (final raw in (data['results'] as List? ?? const [])) {
        final item = Map<String, dynamic>.from(raw as Map);
        results.add(
          DeletionOutcome(
            uid: item['uid'].toString(),
            status: item['status']?.toString() ?? 'failed',
            failedSteps: List<String>.from(item['failedSteps'] as List? ?? []),
            message: item['message']?.toString(),
            requestId: requestId,
          ),
        );
      }
      return BulkDeletionOutcome(results);
    } on FirebaseFunctionsException catch (error) {
      return BulkDeletionOutcome([
        for (final uid in uids)
          DeletionOutcome(
            uid: uid,
            status: 'failed',
            message: error.message ?? 'The request was rejected.',
          ),
      ]);
    }
  }

  @override
  Future<VerificationDetails?> loadVerification(String uid) async {
    final doc = await _firestore
        .collection('verification_requests')
        .doc(uid)
        .get();
    final data = doc.data();
    if (data == null) return null;
    return VerificationDetails(
      request: VerificationRequestModel.fromMap(doc.id, data),
    );
  }

  @override
  Future<String?> documentUrl(String storagePath) =>
      _verification.getPrivateImageUrl(storagePath);

  @override
  Future<void> approveVerification(VerificationRequestModel request) =>
      _verification.approve(request);

  @override
  Future<void> rejectVerification(
    VerificationRequestModel request,
    String reason,
  ) => _verification.reject(request, reason);
}
