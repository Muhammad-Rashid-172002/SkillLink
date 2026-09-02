import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_models.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_repository.dart';

void main() {
  test(
    'coordinate parsing, eligibility, and Haversine distance use real data',
    () {
      final professional = ExploreProfessional(
        id: 'worker-1',
        data: _worker(
          name: 'Ahmed Khan',
          skill: 'AC Repair',
          publicLat: 33.6844,
          publicLng: 73.0479,
        ),
      );
      final blocked = ExploreProfessional(
        id: 'worker-2',
        data: {
          ..._worker(name: 'Blocked', skill: 'Cleaner'),
          'isBlocked': true,
        },
      );

      expect(professional.isEligible, isTrue);
      expect(blocked.isEligible, isFalse);
      expect(professional.publicCoordinate, isNotNull);
      expect(
        publicWorkerCoordinate({'publicLat': 130, 'publicLng': 400}),
        isNull,
      );
      final distance = distanceInKilometers(
        const SkillNovaCoordinate(33.6844, 73.0479),
        const SkillNovaCoordinate(33.6938, 73.0652),
      );
      expect(distance, inInclusiveRange(1.8, 2.0));
    },
  );

  testWidgets('Explore supports search, category, filters, and sort at 390px', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeExploreDataSource(
      profile: _customerWithLocation,
      professionals: [
        ExploreProfessional(
          id: 'worker-1',
          data: _worker(
            name: 'Ahmed Khan',
            skill: 'AC Repair',
            city: 'Islamabad',
            rating: 4.2,
            publicLat: 33.6938,
            publicLng: 73.0652,
          ),
        ),
        ExploreProfessional(
          id: 'worker-2',
          data: _worker(
            name: 'Bilal Ali',
            skill: 'Electrician',
            city: 'Rawalpindi',
            rating: 4.9,
            publicLat: 33.5651,
            publicLng: 73.0169,
          ),
        ),
      ],
    );

    await tester.pumpWidget(_exploreApp(source));
    await tester.pumpAndSettle();

    expect(find.text('Explore professionals'), findsOneWidget);
    expect(find.text('Ahmed Khan'), findsOneWidget);
    expect(find.text('Bilal Ali'), findsOneWidget);
    expect(find.textContaining('km away'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('explore-search')),
      'Rawalpindi',
    );
    await tester.pump();
    expect(find.text('Ahmed Khan'), findsNothing);
    expect(find.text('Bilal Ali'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('explore-search')), '');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-AC Repair')));
    await tester.pump();
    expect(find.text('Ahmed Khan'), findsOneWidget);
    expect(find.text('Bilal Ali'), findsNothing);

    await tester.tap(find.text('Filters (1)'));
    await tester.pumpAndSettle();
    expect(
      find.text('All Explore results are identity verified.'),
      findsOneWidget,
    );
    expect(find.text('Maximum distance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('4.5+ stars'));
    await tester.ensureVisible(find.text('Apply filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('No matching professionals'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Recommended'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recommended'));
    await tester.pumpAndSettle();
    expect(find.text('Nearest'), findsOneWidget);
    await tester.tap(find.text('Highest rated'));
    await tester.pumpAndSettle();
    expect(find.text('Highest rated'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Bilal Ali')).dy,
      lessThan(tester.getTopLeft(find.text('Ahmed Khan')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Explore handles missing location and map with invalid coordinates',
    (tester) async {
      _setSize(tester, const Size(320, 720));
      final source = _FakeExploreDataSource(
        profile: const {'name': 'Customer'},
        professionals: [
          ExploreProfessional(
            id: 'worker-1',
            data: _worker(
              name: 'No Map Location',
              skill: 'Cleaner',
              publicLat: 123,
              publicLng: 456,
            ),
          ),
        ],
      );

      await tester.pumpWidget(_exploreApp(source));
      await tester.pumpAndSettle();
      expect(
        find.text('Enable location to see real distances and nearest sorting.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Recommended'));
      await tester.pumpAndSettle();
      expect(find.text('Nearest'), findsNothing);
      Navigator.of(tester.element(find.text('Sort professionals'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(find.text('No public locations to show'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('map mode creates markers only for valid public coordinates', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeExploreDataSource(
      profile: _customerWithLocation,
      professionals: [
        ExploreProfessional(
          id: 'worker-valid',
          data: _worker(
            name: 'Mapped Professional',
            skill: 'Electrician',
            publicLat: 33.6938,
            publicLng: 73.0652,
          ),
        ),
        ExploreProfessional(
          id: 'worker-invalid',
          data: _worker(
            name: 'List Only Professional',
            skill: 'Cleaner',
            publicLat: 123,
            publicLng: 456,
          ),
        ),
      ],
    );

    await tester.pumpWidget(_exploreApp(source));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map'));
    await tester.pump();

    expect(find.byType(GoogleMap), findsOneWidget);
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers, hasLength(1));
    expect(map.markers.single.markerId.value, 'worker-valid');
    expect(map.markers.single.position, const LatLng(33.6938, 73.0652));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Explore shows polished empty state at 320px', (tester) async {
    _setSize(tester, const Size(320, 720));
    await tester.pumpWidget(
      _exploreApp(
        _FakeExploreDataSource(
          profile: _customerWithLocation,
          professionals: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No professionals available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _customerWithLocation = <String, dynamic>{
  'name': 'Customer',
  'city': 'Islamabad',
  'area': 'F-7',
  'locationAdded': true,
  'lat': 33.6844,
  'lng': 73.0479,
};

Map<String, dynamic> _worker({
  required String name,
  required String skill,
  String city = 'Islamabad',
  double rating = 4.8,
  double? publicLat,
  double? publicLng,
}) {
  return {
    'name': name,
    'skill': skill,
    'city': city,
    'role': 'worker',
    'profileCompleted': true,
    'identityVerificationStatus': 'approved',
    'canAcceptJobs': true,
    'accountStatus': 'active',
    'rating': rating,
    'totalReviews': 12,
    'hourlyRate': 2500,
    'experience': '6 years',
    'publicLat': publicLat,
    'publicLng': publicLng,
  };
}

Widget _exploreApp(ExploreDataSource source) {
  return MaterialApp(
    theme: SkillNovaTheme.light,
    home: Explore(dataSource: source, locationService: _NoLocationService()),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _NoLocationService implements ExploreLocationService {
  @override
  Future<SkillNovaCoordinate?> currentLocation() async => null;
}

class _FakeExploreDataSource implements ExploreDataSource {
  _FakeExploreDataSource({required this.profile, required this.professionals});

  final Map<String, dynamic>? profile;
  final List<ExploreProfessional> professionals;

  @override
  String get customerId => 'customer-1';

  @override
  Future<void> refresh() async {}

  @override
  Stream<Map<String, dynamic>?> watchCustomerProfile() => Stream.value(profile);

  @override
  Stream<List<ExploreProfessional>> watchEligibleProfessionals() =>
      Stream.value(professionals.where((worker) => worker.isEligible).toList());
}
