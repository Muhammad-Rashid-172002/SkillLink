import 'package:skill_link/core/auth/user_role.dart';

/// Where a resolved role came from. Anything other than [stored] means the
/// `users/{uid}.role` field was missing or malformed and must be repaired —
/// by the server (`initializeAccount` Cloud Function), never by the app.
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

  /// Evidence points at both roles. Never guessed.
  conflict,

  /// Nothing usable was found.
  none,
}

class RoleResolution {
  const RoleResolution(this.role, this.source);

  const RoleResolution.none([this.source = RoleSource.none]) : role = null;

  final UserRole? role;
  final RoleSource source;

  bool get isResolved => role != null;

  /// True when the stored document must be repaired by the server.
  bool get needsRepair =>
      role != null && source != RoleSource.stored && source != RoleSource.none;

  @override
  String toString() => 'RoleResolution(${role?.value}, $source)';
}

/// Pure, side-effect free role resolution that mirrors
/// `functions/accounts.js#resolveStoredRole`.
///
/// It only reads data stored on the server. A role remembered on the device
/// or tapped on a login screen is **never** used to decide what an account
/// is: that is what allowed customers to end up in the worker app (and the
/// reverse) on a second device.
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

  static RoleResolution resolve(Map<String, dynamic> data) {
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

    return _profileEvidence(data);
  }

  /// Fields that only one role's flows ever write.
  static RoleResolution _profileEvidence(Map<String, dynamic> data) {
    bool present(String key) {
      final value = data[key];
      if (value == null) return false;
      if (value is String) return value.trim().isNotEmpty;
      if (value is Iterable) return value.isNotEmpty;
      return true;
    }

    final identity =
        data['identityVerificationStatus']?.toString().trim().toLowerCase() ??
        '';
    final level =
        data['verificationLevel']?.toString().trim().toLowerCase() ?? '';

    final workerSignals =
        const ['skill', 'hourlyRate', 'experience', 'skills'].any(present) ||
        (identity.isNotEmpty && identity != 'not_required') ||
        level == 'unverified' ||
        level == 'identity_verified';
    final customerSignals = identity == 'not_required' || level == 'basic';

    if (workerSignals && !customerSignals) {
      return const RoleResolution(UserRole.worker, RoleSource.profileEvidence);
    }
    if (customerSignals && !workerSignals) {
      return const RoleResolution(
        UserRole.customer,
        RoleSource.profileEvidence,
      );
    }
    return RoleResolution.none(
      workerSignals && customerSignals ? RoleSource.conflict : RoleSource.none,
    );
  }
}
