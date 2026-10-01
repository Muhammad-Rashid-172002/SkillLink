/// The single, strongly typed definition of every account role in SkillNova.
///
/// Firestore stores the lowercase [value] in `users/{uid}.role`. Every screen,
/// service and guard must go through this enum instead of comparing raw
/// strings, so that casing, whitespace and legacy spellings can never cause a
/// valid account to be rejected again.
enum UserRole {
  customer('customer', 'Customer'),
  worker('worker', 'Worker'),
  admin('admin', 'Admin');

  const UserRole(this.value, this.label);

  /// Canonical value persisted in Firestore.
  final String value;

  /// Human readable label for UI copy.
  final String label;

  bool get isCustomer => this == UserRole.customer;
  bool get isWorker => this == UserRole.worker;

  /// Roles that can use the mobile app. Admins use the separate admin console.
  bool get isAppRole => this == UserRole.customer || this == UserRole.worker;

  static const Map<String, UserRole> _aliases = {
    'customer': UserRole.customer,
    'customers': UserRole.customer,
    'client': UserRole.customer,
    'buyer': UserRole.customer,
    'hirer': UserRole.customer,
    'worker': UserRole.worker,
    'workers': UserRole.worker,
    'provider': UserRole.worker,
    'serviceprovider': UserRole.worker,
    'service_provider': UserRole.worker,
    'technician': UserRole.worker,
    'professional': UserRole.worker,
    'admin': UserRole.admin,
    'superadmin': UserRole.admin,
    'super_admin': UserRole.admin,
  };

  /// Tolerant parser: trims, lowercases and accepts legacy aliases.
  /// Returns `null` for anything that is not a recognised role.
  static UserRole? tryParse(Object? raw) {
    if (raw == null) return null;
    final normalized = raw
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (normalized.isEmpty) return null;
    return _aliases[normalized] ?? _aliases[normalized.replaceAll('_', '')];
  }
}
