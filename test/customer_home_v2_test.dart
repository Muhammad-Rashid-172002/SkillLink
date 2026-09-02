import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/customer_screens/bottom_bar/bottom_bar.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/customer_home_repository.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/customer_home_screen.dart';

void main() {
  testWidgets('Home renders active booking and eligible professional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = _FakeHomeDataSource(
      profile: {'name': 'Rashid Ahmed', 'city': 'Islamabad', 'area': 'F-10'},
      unreadCount: 2,
      requests: const [
        CustomerHomeRecord(
          id: 'request-1',
          data: {
            'category': 'AC Repair',
            'status': 'on_the_way',
            'workerId': 'worker-1',
          },
        ),
      ],
      professionals: const [
        CustomerHomeRecord(
          id: 'worker-1',
          data: {
            'name': 'Ahmed Khan',
            'skill': 'AC Repair',
            'rating': 4.9,
            'totalReviews': 120,
            'identityVerificationStatus': 'approved',
            'isOnline': true,
          },
        ),
      ],
    );

    await tester.pumpWidget(_homeApp(source));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rashid'), findsOneWidget);
    expect(find.text('F-10, Islamabad'), findsOneWidget);
    expect(find.text('Active booking'), findsOneWidget);
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Ahmed Khan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home handles no active booking and no professionals at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final source = _FakeHomeDataSource(
      profile: {'name': 'Sara Ali'},
      unreadCount: 0,
      requests: const [],
      professionals: const [],
    );

    await tester.pumpWidget(_homeApp(source));
    await tester.pumpAndSettle();

    expect(find.text('Add your service location'), findsOneWidget);
    expect(find.text('Active booking'), findsNothing);
    expect(find.text('No professionals available yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Customer bottom navigation exposes the five V2 destinations', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: SkillNovaTheme.light,
        home: Scaffold(
          bottomNavigationBar: CustomerBottomBar(
            selectedIndex: selected,
            onDestinationSelected: (index) => selected = index,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Bookings'));
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });
}

Widget _homeApp(CustomerHomeDataSource source) {
  return MaterialApp(
    theme: SkillNovaTheme.light,
    darkTheme: SkillNovaTheme.dark,
    home: CustomerHomeScreen(dataSource: source),
  );
}

class _FakeHomeDataSource implements CustomerHomeDataSource {
  _FakeHomeDataSource({
    required this.profile,
    required this.unreadCount,
    required this.requests,
    required this.professionals,
  });

  final Map<String, dynamic>? profile;
  final int unreadCount;
  final List<CustomerHomeRecord> requests;
  final List<CustomerHomeRecord> professionals;

  @override
  String get userId => 'customer-1';

  @override
  Future<void> refresh() async {}

  @override
  Stream<List<CustomerHomeRecord>> watchCustomerRequests() {
    return Stream.value(requests);
  }

  @override
  Stream<List<CustomerHomeRecord>> watchEligibleProfessionals() {
    return Stream.value(professionals);
  }

  @override
  Stream<Map<String, dynamic>?> watchProfile() {
    return Stream.value(profile);
  }

  @override
  Stream<int> watchUnreadNotificationCount() {
    return Stream.value(unreadCount);
  }
}
