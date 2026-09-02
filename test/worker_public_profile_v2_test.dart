import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/worker_public_profile_repository.dart';

void main() {
  testWidgets(
    'public profile shows trust, real details, hydrated reviews, and CTA',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      var requestCount = 0;
      final source = _FakeProfileDataSource(
        worker: _worker(profileImage: 'https://example.com/worker.jpg'),
        reviews: [
          PublicWorkerReview(
            id: 'review-1',
            rating: 5,
            comment: 'Excellent service and careful work.',
            customerName: 'Sara Ali',
            customerPhotoUrl: 'https://example.com/sara.jpg',
            createdAt: DateTime(2026, 8, 20),
            service: 'AC Repair',
            verifiedBooking: true,
          ),
          PublicWorkerReview(
            id: 'review-2',
            rating: 4,
            comment: 'Arrived prepared and fixed the issue.',
            customerName: 'Omar Khan',
            customerPhotoUrl: '',
            createdAt: DateTime(2026, 7, 10),
            service: 'AC Repair',
            verifiedBooking: true,
          ),
        ],
      );

      await tester.pumpWidget(
        _profileApp(source, onRequest: () => requestCount++, distanceKm: 2.4),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.text('Identity verified'), findsOneWidget);
      expect(find.text('Phone verified'), findsOneWidget);
      expect(find.text('6 years'), findsOneWidget);
      expect(find.text('Rs 2500/hr'), findsOneWidget);
      expect(find.text('2.4 km away'), findsOneWidget);
      expect(find.text('Excellent service and careful work.'), findsOneWidget);
      expect(find.text('Sara Ali'), findsOneWidget);
      expect(find.text('Verified booking'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('avatar-image-Ahmed Khan')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('avatar-image-Sara Ali')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('avatar-fallback-Omar Khan')),
        findsOneWidget,
      );

      await tester.tap(find.text('Request service'));
      expect(requestCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('public profile handles missing photos and no reviews at 320px', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 720));
    final source = _FakeProfileDataSource(
      worker: _worker(profileImage: '', rating: 0, totalReviews: 0),
      reviews: const [],
    );

    await tester.pumpWidget(
      _profileApp(source, onRequest: () {}, textScale: 1.15),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('avatar-fallback-Ahmed Khan')),
      findsOneWidget,
    );
    expect(find.text('New professional'), findsOneWidget);
    expect(find.text('No public reviews yet'), findsOneWidget);
    expect(find.text('Request service'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> _worker({
  required String profileImage,
  double rating = 4.9,
  int totalReviews = 28,
}) {
  return {
    'name': 'Ahmed Khan',
    'skill': 'AC Repair',
    'city': 'Islamabad',
    'role': 'worker',
    'profileCompleted': true,
    'identityVerificationStatus': 'approved',
    'canAcceptJobs': true,
    'accountStatus': 'active',
    'profileImage': profileImage,
    'rating': rating,
    'totalReviews': totalReviews,
    'bio': 'Residential cooling specialist focused on dependable repairs.',
    'experience': '6 years',
    'hourlyRate': 2500,
    'phoneVerified': true,
  };
}

Widget _profileApp(
  WorkerPublicProfileDataSource source, {
  required VoidCallback onRequest,
  double? distanceKm,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: SkillNovaTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: WorkerPublicProfileScreen(
      workerId: 'worker-1',
      distanceKm: distanceKm,
      dataSource: source,
      onRequestService: onRequest,
      onMessage: () {},
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeProfileDataSource implements WorkerPublicProfileDataSource {
  _FakeProfileDataSource({required this.worker, required this.reviews});

  final Map<String, dynamic>? worker;
  final List<PublicWorkerReview> reviews;

  @override
  Future<void> refresh(String workerId) async {}

  @override
  Stream<List<PublicWorkerReview>> watchReviews(String workerId) =>
      Stream.value(reviews);

  @override
  Stream<Map<String, dynamic>?> watchWorker(String workerId) =>
      Stream.value(worker);
}
