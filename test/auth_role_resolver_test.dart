import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/core/auth/role_resolver.dart';
import 'package:skill_link/core/auth/user_role.dart';

void main() {
  group('UserRole.tryParse', () {
    test('accepts canonical values', () {
      expect(UserRole.tryParse('customer'), UserRole.customer);
      expect(UserRole.tryParse('worker'), UserRole.worker);
      expect(UserRole.tryParse('admin'), UserRole.admin);
    });

    test('is tolerant of casing, whitespace and legacy aliases', () {
      expect(UserRole.tryParse(' Customer '), UserRole.customer);
      expect(UserRole.tryParse('WORKER'), UserRole.worker);
      expect(UserRole.tryParse('Service Provider'), UserRole.worker);
      expect(UserRole.tryParse('service-provider'), UserRole.worker);
      expect(UserRole.tryParse('client'), UserRole.customer);
    });

    test('rejects garbage', () {
      expect(UserRole.tryParse(null), isNull);
      expect(UserRole.tryParse(''), isNull);
      expect(UserRole.tryParse('   '), isNull);
      expect(UserRole.tryParse('banana'), isNull);
      expect(UserRole.tryParse(42), isNull);
    });
  });

  group('RoleResolver', () {
    test('canonical stored role needs no repair', () {
      final r = RoleResolver.resolve({'role': 'customer'});
      expect(r.role, UserRole.customer);
      expect(r.source, RoleSource.stored);
      expect(r.needsPersist, isFalse);
    });

    test('non-canonical stored role is normalised and repaired', () {
      final r = RoleResolver.resolve({'role': 'Worker '});
      expect(r.role, UserRole.worker);
      expect(r.source, RoleSource.storedNonCanonical);
      expect(r.needsPersist, isTrue);
    });

    test('stored role always beats the role picked on the login screen', () {
      final r = RoleResolver.resolve(
        {'role': 'worker'},
        selectedRole: UserRole.customer,
      );
      expect(r.role, UserRole.worker);
    });

    test('legacy userType field is recovered', () {
      final r = RoleResolver.resolve({'userType': 'customer'});
      expect(r.role, UserRole.customer);
      expect(r.source, RoleSource.legacyField);
      expect(r.needsPersist, isTrue);
    });

    test(
      'half-created document (only fcmToken, the original bug) falls back '
      'to the role remembered at sign-up',
      () {
        final r = RoleResolver.resolve(
          {'fcmToken': 'abc'},
          cachedRole: UserRole.worker,
          selectedRole: UserRole.customer,
        );
        expect(r.role, UserRole.worker);
        expect(r.source, RoleSource.deviceCache);
      },
    );

    test('customer sign-up defaults identify a customer', () {
      final r = RoleResolver.resolve({
        'identityVerificationStatus': 'not_required',
        'verificationLevel': 'basic',
      });
      expect(r.role, UserRole.customer);
      expect(r.source, RoleSource.profileEvidence);
    });

    test('worker-only fields identify a worker', () {
      expect(
        RoleResolver.resolve({'skill': 'Plumber'}).role,
        UserRole.worker,
      );
      expect(
        RoleResolver.resolve({
          'identityVerificationStatus': 'pending',
        }).role,
        UserRole.worker,
      );
    });

    test('profile evidence beats a mismatched login selection', () {
      final r = RoleResolver.resolve(
        {'hourlyRate': '1500'},
        selectedRole: UserRole.customer,
      );
      expect(r.role, UserRole.worker);
    });

    test('login selection is the last resort', () {
      final r = RoleResolver.resolve(
        const {},
        selectedRole: UserRole.customer,
      );
      expect(r.role, UserRole.customer);
      expect(r.source, RoleSource.userSelection);
    });

    test('admin selection is never used to recover an account', () {
      final r = RoleResolver.resolve(
        const {},
        cachedRole: UserRole.admin,
        selectedRole: UserRole.admin,
      );
      expect(r.isResolved, isFalse);
    });

    test('nothing to go on -> unresolved (role recovery screen)', () {
      final r = RoleResolver.resolve(const {'name': 'Sam'});
      expect(r.isResolved, isFalse);
      expect(r.source, RoleSource.none);
    });
  });
}
