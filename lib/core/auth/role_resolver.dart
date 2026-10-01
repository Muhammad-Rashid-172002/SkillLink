import 'package:skill_link/core/auth/user_role.dart';

/// Where a resolved role came from. Anything other than [stored] means the
/// `users/{uid}.role` field was missing or malformed and should be repaired.
enum RoleSource {
  /// `role` field exists and is already in canonical form.
  stored,

  /// `role` exists but with different casing/spacing/alias (e.g. "Customer ").
  storedNonCanonical,

  /// Found in a legacy field such as `userType` or `accountType`.
  legacyField,

  /// Inferred from fields only one role ever writes (worker skill, customer
  /// verification defaults, ...).
  profileEvidence,

  /// Role remembered on this device when the account was created.
  deviceCache,

  /// Role the person explicitly picked on the role selection screen.
  userSelection,

  /// Nothing usable was found.
  none,
}

class RoleResolution {
  const RoleResolution(this.role, this.source);

  const RoleResolution.none() : role = null, source = RoleSource.none;

  final UserRole? role;
  final RoleSource source;

  bool get isResolved => role != null;

  /// True when the stored document must be repaired with the canonical value.
  bool get needsPersist =>
      role != null && source != RoleSource.stored && source != RoleSource.none;

  @override
  String toString() => 'RoleResolution(${role?.value}, $source)';
}

/// Pure, side-effect free role resolution.
///
/// This is the root-cause fix for the "Account role is invalid" bug: instead of
/// rejecting any document whose `role` field is not exactly `customer` or
/// `worker`, we recover the role from every trustworthy signal, in order of
/// reliability, and only give up when the account genuinely has no role.
abstract final class RoleResolver {
  static const List<String> legacyRoleKeys = [
    'userType',
    'user_type',
    'accountType',
    'account_type',
    'userRole',
    'user_role',
    'type',
  ];

  static RoleResolution resolve(
    Map<String, dynamic> data, {
    UserRole? cachedRole,
    UserRole? selectedRole,
  }) {
    final raw = data['role'];
    final stored = UserRole.tryParse(raw);
    if (stored != null) {
      final canonical = raw is String && raw == stored.value;
      return RoleResolution(
        stored,
        canonical ? RoleSource.stored : RoleSource.storedNonCanonical,
      );
    }

    for (final key in legacyRoleKeys) {
      final legacy = UserRole.tryParse(data[key]);
      if (legacy != null) return RoleResolution(legacy, RoleSource.legacyField);
    }

    final evidence = _profileEvidence(data);
    if (evidence != null) {
      return RoleResolution(evidence, RoleSource.profileEvidence);
    }

    if (cachedRole != null && cachedRole.isAppRole) {
      return RoleResolution(cachedRole, RoleSource.deviceCache);
    }

    if (selectedRole != null && selectedRole.isAppRole) {
      return RoleResolution(selectedRole, RoleSource.userSelection);
    }

    return const RoleResolution.none();
  }

  /// Fields that only one role's flows ever write.
  static UserRole? _profileEvidence(Map<String, dynamic> data) {
    bool present(String key) {
      final value = data[key];
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      if (value is Iterable) return value.isNotEmpty;
      return true;
    }

    final identity = data['identityVerificationStatus']
        ?.toString()
        .trim()
        .toLowerCase();
    final level = data['verificationLevel']?.toString().trim().toLowerCase();

    // Customer sign-up always writes these exact defaults.
    if (identity == 'not_required' || level == 'basic') {
      return UserRole.customer;
    }

    // Only the worker profile / verification flows write these.
    final workerSignals = [
      'skill',
      'hourlyRate',
      'experience',
      'skills',
    ].any(present);
    final workerVerification =
        identity != null && identity.isNotEmpty && identity != 'not_required';
    if (workerSignals ||
        workerVerification ||
        level == 'unverified' ||
        level == 'identity_verified') {
      return UserRole.worker;
    }

    return null;
  }
}
