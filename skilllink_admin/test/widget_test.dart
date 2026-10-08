// Replaces Flutter's default "counter increments" template test, which tested
// a counter this app never had and so could never pass.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skilllink_admin/theme/admin_design.dart';
import 'package:skilllink_admin/widgets/dashboard_stat_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: Center(child: SizedBox(width: 260, child: child)),
    ),
  );

  testWidgets('KPI card shows label, value and context', (tester) async {
    await tester.pumpWidget(
      host(
        const DashboardStatCard(
          title: 'Open requests',
          value: '12',
          icon: Icons.schedule_rounded,
          accent: kAdminWarning,
          subtitle: 'Waiting for a professional',
        ),
      ),
    );
    expect(find.text('Open requests'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Waiting for a professional'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KPI card is tappable when it links to a section', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      host(
        DashboardStatCard(
          title: 'Workers',
          value: '4',
          icon: Icons.engineering_outlined,
          accent: kAdminBrand,
          subtitle: 'Registered professionals',
          onTap: () => opened = true,
        ),
      ),
    );
    await tester.tap(find.byType(DashboardStatCard));
    expect(opened, isTrue);
  });

  test('admin theme uses the SkillNova brand, not the old green', () {
    final theme = AdminTheme.light;
    expect(theme.colorScheme.primary, kAdminBrand);
    expect(theme.colorScheme.primary, isNot(const Color(0xFF16A34A)));
    // Green is reserved for success states.
    expect(kAdminSuccess, isNot(kAdminBrand));
  });
}
