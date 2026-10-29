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
      expect(r.needsRepair, isFalse);
    });

    test('non-canonical stored role is normalised and repaired', () {
      final r = RoleResolver.resolve({'role': 'Worker '});
      expect(r.role, UserRole.worker);
      expect(r.source, RoleSource.storedNonCanonical);
      expect(r.needsRepair, isTrue);
    });

    test('legacy userType field is recovered', () {
      final r = RoleResolver.resolve({'userType': 'customer'});
      expect(r.role, UserRole.customer);
      expect(r.source, RoleSource.legacyField);
      expect(r.needsRepair, isTrue);
    });

    test('half-created document (only fcmToken, the original bug) is NOT '
        'resolved on the device: the server decides', () {
      final r = RoleResolver.resolve({'fcmToken': 'abc'});
      expect(r.isResolved, isFalse);
      expect(r.source, RoleSource.none);
    });

    test('customer sign-up defaults identify a customer', () {
      final r = RoleResolver.resolve({
        'identityVerificationStatus': 'not_required',
        'verificationLevel': 'basic',
      });
      expect(r.role, UserRole.customer);
      expect(r.source, RoleSource.profileEvidence);
    });

    test('worker-only fields identify a worker', () {
      expect(RoleResolver.resolve({'skill': 'Plumber'}).role, UserRole.worker);
      expect(
        RoleResolver.resolve({'identityVerificationStatus': 'pending'}).role,
        UserRole.worker,
      );
    });

    test('contradictory evidence is never guessed', () {
      final r = RoleResolver.resolve({
        'skill': 'Plumber',
        'identityVerificationStatus': 'not_required',
      });
      expect(r.isResolved, isFalse);
      expect(r.source, RoleSource.conflict);
    });

    test('admin stored role is reported as admin (app then refuses it)', () {
      expect(RoleResolver.resolve({'role': 'admin'}).role, UserRole.admin);
    });

    test('nothing to go on -> unresolved (role recovery screen)', () {
      final r = RoleResolver.resolve(const {'name': 'Sam'});
      expect(r.isResolved, isFalse);
      expect(r.source, RoleSource.none);
    });
  });
}
