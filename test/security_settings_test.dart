import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/screens/shared/security_settings_section.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: ListView(children: [child])));

  testWidgets('email/password accounts can request a reset link', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SecuritySettingsSection(
          hasPassword: true,
          email: 'ayesha@example.com',
        ),
      ),
    );
    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);

    await tester.tap(find.byKey(const Key('change-password')));
    await tester.pumpAndSettle();
    // Nothing is sent without an explicit confirmation.
    expect(find.text('Change your password?'), findsOneWidget);
    expect(find.textContaining('ayesha@example.com'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Change your password?'), findsNothing);
  });

  testWidgets('Google-only accounts are pointed to Google', (tester) async {
    await tester.pumpWidget(
      host(const SecuritySettingsSection(hasPassword: false)),
    );
    expect(find.text('Change password'), findsNothing);
    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });
}
