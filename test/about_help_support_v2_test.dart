import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/shared/skillnova_about.dart';
import 'package:skill_link/screens/shared/skillnova_help_support.dart';

void main() {
  testWidgets('About dialog shows approved branding and dynamic package data', (
    tester,
  ) async {
    await _openAbout(tester, packageInfo: _packageInfo('2.4.6', '108'));

    expect(
      find.byKey(const ValueKey('skillnova-about-dialog')),
      findsOneWidget,
    );
    expect(find.text('SkillNova'), findsOneWidget);
    expect(find.text('Local services, made simple.'), findsOneWidget);
    expect(
      find.text(
        'SkillNova connects customers with trusted local professionals for everyday services.',
      ),
      findsOneWidget,
    );
    expect(find.text('Version 2.4.6 (108)'), findsOneWidget);
    expect(find.text('A product of Korvenza Technologies'), findsOneWidget);
    expect(
      find.text('© 2026 Korvenza Technologies. All rights reserved.'),
      findsOneWidget,
    );
    expect(find.text('Visit Website'), findsNothing);
    expect(find.textContaining('RashidApps'), findsNothing);
    expect(find.textContaining('Muhammad Rashid'), findsNothing);
    expect(find.textContaining('Flutter'), findsNothing);
    expect(find.textContaining('Firebase'), findsNothing);
    expect(find.textContaining('Production'), findsNothing);
  });

  testWidgets('About close dismisses the dialog', (tester) async {
    await _openAbout(tester);
    await tester.tap(find.byKey(const ValueKey('close-about')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skillnova-about-dialog')), findsNothing);
    expect(find.text('Open About'), findsOneWidget);
  });

  testWidgets('About Privacy action closes the modal before navigation', (
    tester,
  ) async {
    await _openAbout(tester);
    await _tapAboutAction(tester, 'about-privacy');
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Open the current Privacy Policy'), findsOneWidget);
    expect(find.byKey(const ValueKey('skillnova-about-dialog')), findsNothing);
  });

  testWidgets('About Terms action presents honest unavailable state', (
    tester,
  ) async {
    await _openAbout(tester);
    await _tapAboutAction(tester, 'about-terms');
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Terms of Service is not available'), findsOneWidget);
    expect(find.textContaining('No approved document'), findsOneWidget);
  });

  testWidgets('About Help action routes to the canonical Help screen', (
    tester,
  ) async {
    await _openAbout(tester);
    await _tapAboutAction(tester, 'about-help');
    expect(find.byKey(const ValueKey('help-support-content')), findsOneWidget);
    expect(find.text('Customer help topics'), findsOneWidget);
    expect(find.byKey(const ValueKey('skillnova-about-dialog')), findsNothing);
  });

  testWidgets('About licenses opens Flutter standard license page', (
    tester,
  ) async {
    await _openAbout(tester);
    await _tapAboutAction(tester, 'about-licenses');
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.byKey(const ValueKey('skillnova-about-dialog')), findsNothing);
  });

  testWidgets('Help email uses exact centralized address and subject', (
    tester,
  ) async {
    Uri? launched;
    await tester.pumpWidget(
      _app(
        SkillNovaHelpSupportScreen(
          audience: SkillNovaHelpAudience.customer,
          safetyBuilder: (_) => const _SafetyStub(),
          launchExternal: (uri) async {
            launched = uri;
            return true;
          },
        ),
      ),
    );

    expect(SkillNovaSupportConfig.supportEmail, 'support@korvennzatech');
    expect(find.text('support@korvennzatech'), findsOneWidget);
    expect(find.textContaining('muhammadrashid172002@gmail.com'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('email-support')));
    await tester.pump();
    expect(launched?.scheme, 'mailto');
    expect(launched?.path, 'support@korvennzatech');
    expect(launched?.queryParameters['subject'], 'SkillNova Support Request');
  });

  testWidgets('Help content is role-specific and does not make fake claims', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SkillNovaHelpSupportScreen(
          key: const ValueKey('customer-help'),
          audience: SkillNovaHelpAudience.customer,
          safetyBuilder: (_) => const _SafetyStub(),
        ),
      ),
    );
    await _expectHelpTopics(tester, const [
      'Finding Professionals',
      'Booking / Requests',
      'Messages',
      'Reviews',
      'Account & Profile',
      'Safety',
    ]);
    expect(find.text('Leads & Lead Credits'), findsNothing);

    await tester.pumpWidget(
      _app(
        SkillNovaHelpSupportScreen(
          key: const ValueKey('worker-help'),
          audience: SkillNovaHelpAudience.worker,
          safetyBuilder: (_) => const _SafetyStub(),
        ),
      ),
    );
    await _expectHelpTopics(tester, const [
      'Leads & Lead Credits',
      'Verification',
      'Accepting Jobs / Readiness',
      'Jobs & Job Status',
      'Messages',
      'Reviews',
      'Account & Profile',
      'Safety',
    ]);
    expect(find.text('Finding Professionals'), findsNothing);
    expect(find.textContaining('24/7'), findsNothing);
    expect(find.textContaining('live agent'), findsNothing);
    expect(find.textContaining('guaranteed response'), findsNothing);
    expect(find.textContaining('automatic police'), findsNothing);
    expect(find.textContaining('instant verification'), findsNothing);
  });

  testWidgets('Help support actions route to Privacy Terms Safety and About', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SkillNovaHelpSupportScreen(
          audience: SkillNovaHelpAudience.worker,
          safetyBuilder: (_) => const _SafetyStub(),
          packageInfo: _packageInfo('3.0.0', '77'),
        ),
      ),
    );

    await _tapSupportAction(tester, 1);
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('Privacy Policy'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tapSupportAction(tester, 2);
    expect(find.text('Terms of Service is not available'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tapSupportAction(tester, 3);
    expect(find.text('Existing safety destination'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tapSupportAction(tester, 4);
    expect(
      find.byKey(const ValueKey('skillnova-about-dialog')),
      findsOneWidget,
    );
    expect(find.text('Version 3.0.0 (77)'), findsOneWidget);
    await _tapAboutAction(tester, 'about-help');
    expect(find.byKey(const ValueKey('skillnova-about-dialog')), findsNothing);
    expect(find.byKey(const ValueKey('help-support-content')), findsOneWidget);
  });

  for (final scenario in const [
    (Size(320, 720), ThemeMode.light),
    (Size(390, 844), ThemeMode.dark),
  ]) {
    testWidgets(
      'About and Help avoid overflow at ${scenario.$1.width.toInt()}x${scenario.$1.height.toInt()} ${scenario.$2.name}',
      (tester) async {
        await _setSize(tester, scenario.$1);
        await _openAbout(
          tester,
          themeMode: scenario.$2,
          textScaler: const TextScaler.linear(1.35),
          packageInfo: _packageInfo(
            '2026.09.14-international-release-candidate',
            '12345678901234567890',
          ),
        );
        await tester.drag(
          find.byKey(const ValueKey('skillnova-about-scroll')),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('close-about')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _app(
            SkillNovaHelpSupportScreen(
              audience: SkillNovaHelpAudience.worker,
              safetyBuilder: (_) => const _SafetyStub(),
            ),
            themeMode: scenario.$2,
            textScaler: const TextScaler.linear(1.35),
          ),
        );
        await tester.drag(
          find.byKey(const ValueKey('help-support-content')),
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _openAbout(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
  Future<PackageInfo>? packageInfo,
}) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showSkillNovaAboutDialog(
                context,
                packageInfo: packageInfo ?? _packageInfo('1.1.1', '9'),
                helpBuilder: (_) => SkillNovaHelpSupportScreen(
                  audience: SkillNovaHelpAudience.customer,
                  safetyBuilder: (_) => const _SafetyStub(),
                ),
              ),
              child: const Text('Open About'),
            ),
          ),
        ),
      ),
      themeMode: themeMode,
      textScaler: textScaler,
    ),
  );
  await tester.tap(find.text('Open About'));
  await tester.pumpAndSettle();
}

Future<void> _tapAboutAction(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('skillnova-about-dialog')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tapSupportAction(WidgetTester tester, int index) async {
  final target = find.byKey(ValueKey('support-action-$index'));
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<PackageInfo> _packageInfo(String version, String buildNumber) async =>
    PackageInfo(
      appName: 'SkillNova',
      packageName: 'com.skillnova.app',
      version: version,
      buildNumber: buildNumber,
      buildSignature: '',
    );

Widget _app(
  Widget home, {
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: SkillNovaTheme.light,
  darkTheme: SkillNovaTheme.dark,
  themeMode: themeMode,
  home: MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: home,
  ),
);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _SafetyStub extends StatelessWidget {
  const _SafetyStub();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Existing safety destination')),
  );
}

Future<void> _expectHelpTopics(WidgetTester tester, List<String> titles) async {
  for (final title in titles) {
    final target = find.text(title);
    await tester.scrollUntilVisible(
      target,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(target, findsOneWidget);
  }
}
