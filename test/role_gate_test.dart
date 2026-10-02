import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/core/auth/auth_session_service.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/core/auth/user_role.dart';

/// QA tests 12 & 13: a role-specific area must never render for a session
/// whose verified role is different, whatever client-side navigation got the
/// person there. (Firestore rules enforce the same boundary server-side.)
void main() {
  final service = AuthSessionService.instance;

  tearDown(() => service.verifiedRole.value = null);

  late int redirects;

  setUp(() => redirects = 0);

  Future<void> pumpGate(WidgetTester tester, UserRole gateRole) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoleGate(
          role: gateRole,
          onRoleMismatch: (_) async => redirects++,
          child: Text('${gateRole.value}-area'),
        ),
      ),
    );
  }

  testWidgets('worker area never renders for a verified customer', (
    tester,
  ) async {
    service.verifiedRole.value = UserRole.customer;
    await pumpGate(tester, UserRole.worker);
    expect(find.text('worker-area'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('worker-area'), findsNothing);
    expect(redirects, 1);
  });

  testWidgets('customer area never renders for a verified worker', (
    tester,
  ) async {
    service.verifiedRole.value = UserRole.worker;
    await pumpGate(tester, UserRole.customer);
    expect(find.text('customer-area'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('customer-area'), findsNothing);
    expect(redirects, 1);
  });

  testWidgets('matching verified role renders the protected area', (
    tester,
  ) async {
    service.verifiedRole.value = UserRole.worker;
    await pumpGate(tester, UserRole.worker);
    await tester.pump();
    expect(find.text('worker-area'), findsOneWidget);
    expect(redirects, 0);
  });

  testWidgets('area hides immediately when the verified role is cleared', (
    tester,
  ) async {
    service.verifiedRole.value = UserRole.customer;
    await pumpGate(tester, UserRole.customer);
    await tester.pump();
    expect(find.text('customer-area'), findsOneWidget);
    service.verifiedRole.value = null;
    await tester.pump();
    expect(find.text('customer-area'), findsNothing);
    expect(redirects, 1);
  });
}
