import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_detail_screen.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_models.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_repository.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_status.dart';
import 'package:skill_link/screens/customer_screens/bookings/customer_bookings_screen.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/request_tracking_screen.dart';

void main() {
  test('all current and legacy statuses normalize centrally', () {
    expect(
      bookingStatusOf('searching').semantic,
      BookingSemanticStatus.searching,
    );
    expect(
      bookingStatusOf('pending').semantic,
      BookingSemanticStatus.searching,
    );
    expect(
      bookingStatusOf('requested').semantic,
      BookingSemanticStatus.searching,
    );
    expect(
      bookingStatusOf('waiting_worker').semantic,
      BookingSemanticStatus.waitingWorker,
    );
    expect(
      bookingStatusOf('accepted').semantic,
      BookingSemanticStatus.accepted,
    );
    expect(
      bookingStatusOf('on the way').semantic,
      BookingSemanticStatus.onTheWay,
    );
    expect(
      bookingStatusOf('ontheway').semantic,
      BookingSemanticStatus.onTheWay,
    );
    expect(
      bookingStatusOf('in progress').semantic,
      BookingSemanticStatus.inProgress,
    );
    expect(
      bookingStatusOf('started').semantic,
      BookingSemanticStatus.inProgress,
    );
    expect(bookingStatusOf('completed').group, BookingGroup.completed);
    expect(bookingStatusOf('cancelled').group, BookingGroup.cancelled);
    expect(bookingStatusOf('canceled').group, BookingGroup.cancelled);
    expect(bookingStatusOf('rejected').group, BookingGroup.cancelled);
    expect(canCancelBookingStatus('searching'), isTrue);
    expect(canCancelBookingStatus('waiting_worker'), isTrue);
    expect(canCancelBookingStatus('accepted'), isFalse);
    expect(canCancelBookingStatus('in_progress'), isFalse);
    expect(canCancelBookingStatus('completed'), isFalse);
  });

  test(
    'coordinates require valid real values and timestamped worker tracking',
    () {
      final booking = CustomerBooking(
        id: 'request-1',
        data: const {
          'status': 'on_the_way',
          'latitude': 33.6844,
          'longitude': 73.0479,
        },
        worker: {
          'lat': 33.6938,
          'lng': 73.0652,
          'locationUpdatedAt': DateTime(2026, 9, 2),
        },
      );
      expect(booking.customerCoordinate, isNotNull);
      expect(booking.workerTrackingCoordinate, isNotNull);
      expect(
        CustomerBooking(
          id: 'bad',
          data: const {
            'status': 'on_the_way',
            'latitude': 140,
            'longitude': 400,
          },
          worker: const {'lat': 33.6, 'lng': 73.0},
        ).workerTrackingCoordinate,
        isNull,
      );
    },
  );

  testWidgets('Bookings groups every lifecycle and review state at 390px', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeBookingsDataSource([
      _booking('searching', service: 'Cleaner'),
      _booking('waiting_worker', service: 'Plumber'),
      _booking('accepted', service: 'Electrician', assigned: true),
      _booking('on_the_way', service: 'AC Repair', assigned: true),
      _booking('in_progress', service: 'Carpenter', assigned: true, photo: ''),
      _booking('completed', service: 'Painting', assigned: true),
      _booking(
        'completed',
        service: 'Appliance Repair',
        assigned: true,
        review: const {'rating': 5},
      ),
      _booking('cancelled', service: 'Gardener'),
    ]);

    await tester.pumpWidget(_app(CustomerBookingsScreen(dataSource: source)));
    await tester.pumpAndSettle();

    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Finding a professional'), findsOneWidget);
    expect(find.text('Waiting for professional'), findsOneWidget);
    expect(find.text('Professional assigned'), findsOneWidget);
    expect(find.text('Professional on the way'), findsOneWidget);
    expect(find.text('Service in progress'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking-worker-fallback-Ahmed Khan')),
      findsWidgets,
    );

    await tester.tap(find.byKey(const ValueKey('booking-tab-completed')));
    await tester.pump();
    expect(find.text('Painting'), findsOneWidget);
    expect(find.text('Rate service'), findsOneWidget);
    expect(find.text('Your rating: 5 stars'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-tab-cancelled')));
    await tester.pump();
    expect(find.text('Gardener'), findsOneWidget);
    expect(find.text('Cancelled'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bookings shows narrow empty states without overflow', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 720));
    await tester.pumpWidget(
      _app(
        CustomerBookingsScreen(dataSource: _FakeBookingsDataSource(const [])),
        textScale: 1.15,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No active bookings'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('booking-tab-completed')));
    await tester.pump();
    expect(find.text('No completed bookings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bookings follows the Step 1 dark theme', (tester) async {
    _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        CustomerBookingsScreen(dataSource: _FakeBookingsDataSource(const [])),
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Bookings'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Booking Detail shows assigned worker, data, image, map and tracking CTA',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      var tracked = 0;
      final source = _FakeDetailDataSource(
        request: _request(
          'on_the_way',
          assigned: true,
          images: const ['https://example.com/request.jpg'],
          validLocation: true,
        ),
        worker: _worker(photo: 'https://example.com/worker.jpg'),
      );
      await tester.pumpWidget(
        _app(
          BookingDetailScreen(
            requestId: 'request-1',
            dataSource: source,
            onTrack: () => tracked++,
            onMessage: () {},
            onCall: () {},
            onViewProfile: () {},
            onSos: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Professional on the way'), findsOneWidget);
      expect(find.text('Ahmed Khan'), findsOneWidget);
      expect(find.text('Posted budget'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('booking-detail-image-0')),
        findsOneWidget,
      );
      final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers.single.markerId.value, 'customer-location');
      await tester.ensureVisible(find.text('Track service'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track service'));
      expect(tracked, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Booking Detail supports safe cancellation only before service', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 720));
    var cancelled = 0;
    final source = _FakeDetailDataSource(request: _request('searching'));
    await tester.pumpWidget(
      _app(
        BookingDetailScreen(
          requestId: 'request-1',
          dataSource: source,
          onCancel: () => cancelled++,
        ),
        textScale: 1.1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancel request'), findsOneWidget);
    expect(find.text('Professional on the way'), findsNothing);
    expect(find.byType(GoogleMap), findsNothing);
    await tester.ensureVisible(find.text('Cancel request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel request'));
    expect(cancelled, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Booking Detail shows an existing submitted review once', (
    tester,
  ) async {
    _setSize(tester, const Size(320, 720));
    final source = _FakeDetailDataSource(
      request: _request('completed', assigned: true),
      worker: _worker(photo: ''),
      review: const {'rating': 5},
    );
    await tester.pumpWidget(
      _app(
        BookingDetailScreen(
          requestId: 'request-1',
          dataSource: source,
          onMessage: () {},
          onViewProfile: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rated 5 stars'), findsOneWidget);
    expect(find.text('Rate service'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tracking uses both valid markers and no route polyline', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    final source = _FakeDetailDataSource(
      request: _request('on_the_way', assigned: true, validLocation: true),
      worker: _worker(
        photo: '',
        latitude: 33.6938,
        longitude: 73.0652,
        locationUpdatedAt: DateTime(2026, 9, 2, 12, 30),
      ),
    );
    await tester.pumpWidget(
      _app(
        RequestTrackingScreen(
          requestId: 'request-1',
          dataSource: source,
          onMessage: () {},
          onCall: () {},
          onViewProfile: () {},
          onSos: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers.map((marker) => marker.markerId.value), {
      'customer-location',
      'worker-location',
    });
    expect(map.polylines, isEmpty);
    expect(
      find.textContaining('Professional location last updated'),
      findsOneWidget,
    );
    expect(find.text('Safety support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Tracking explains unavailable worker location and missing coordinates',
    (tester) async {
      _setSize(tester, const Size(320, 720));
      final source = _FakeDetailDataSource(
        request: _request('on_the_way', assigned: true),
        worker: _worker(photo: '', latitude: 33.6, longitude: 73.0),
      );
      await tester.pumpWidget(
        _app(
          RequestTrackingScreen(
            requestId: 'request-1',
            dataSource: source,
            onMessage: () {},
            onViewProfile: () {},
            onSos: () {},
          ),
          textScale: 1.1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live location is not available yet.'), findsOneWidget);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.byType(GoogleMap), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Tracking completion connects to the existing review flow', (
    tester,
  ) async {
    _setSize(tester, const Size(390, 844));
    var ratingsOpened = 0;
    final source = _FakeDetailDataSource(
      request: _request('completed', assigned: true),
      worker: _worker(photo: ''),
    );
    await tester.pumpWidget(
      _app(
        RequestTrackingScreen(
          requestId: 'request-1',
          dataSource: source,
          onMessage: () {},
          onViewProfile: () {},
          onRate: () => ratingsOpened++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Rate service'), findsOneWidget);
    await tester.ensureVisible(find.text('Rate service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rate service'));
    expect(ratingsOpened, 1);
    expect(tester.takeException(), isNull);
  });
}

CustomerBooking _booking(
  String status, {
  required String service,
  bool assigned = false,
  String photo = 'https://example.com/worker.jpg',
  Map<String, dynamic>? review,
}) {
  final request = _request(status, assigned: assigned);
  request['category'] = service;
  return CustomerBooking(
    id: 'request-$status-$service',
    data: request,
    worker: assigned ? _worker(photo: photo) : null,
    review: review,
  );
}

Map<String, dynamic> _request(
  String status, {
  bool assigned = false,
  List<String> images = const [],
  bool validLocation = false,
}) {
  return {
    'customerId': 'customer-1',
    'status': status,
    'category': 'AC Repair',
    'title': 'Repair cooling unit',
    'description': 'The unit is not cooling properly.',
    'location': validLocation ? 'F-7, Islamabad' : '',
    'budget': '2500',
    'urgency': 'Normal',
    'createdAt': DateTime(2026, 9, 1, 10, 30),
    'imageUrls': images,
    if (assigned) 'workerId': 'worker-1',
    if (validLocation) 'latitude': 33.6844,
    if (validLocation) 'longitude': 73.0479,
  };
}

Map<String, dynamic> _worker({
  required String photo,
  double? latitude,
  double? longitude,
  DateTime? locationUpdatedAt,
}) {
  return {
    'name': 'Ahmed Khan',
    'skill': 'AC Repair',
    'profileImage': photo,
    'phone': '+923001234567',
    'rating': 4.9,
    'identityVerificationStatus': 'approved',
    'lat': latitude,
    'lng': longitude,
    'locationUpdatedAt': locationUpdatedAt,
  };
}

Widget _app(
  Widget home, {
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: SkillNovaTheme.light,
    darkTheme: SkillNovaTheme.dark,
    themeMode: themeMode,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeBookingsDataSource implements CustomerBookingsDataSource {
  _FakeBookingsDataSource(this.bookings);

  final List<CustomerBooking> bookings;

  @override
  String get customerId => 'customer-1';

  @override
  Future<void> cancelPreServiceRequest(String requestId) async {}

  @override
  Future<void> refreshBookings() async {}

  @override
  Stream<List<CustomerBooking>> watchBookings() => Stream.value(bookings);
}

class _FakeDetailDataSource implements BookingDetailDataSource {
  _FakeDetailDataSource({required this.request, this.worker, this.review});

  final Map<String, dynamic>? request;
  final Map<String, dynamic>? worker;
  final Map<String, dynamic>? review;

  @override
  Future<void> cancelPreServiceRequest(String requestId) async {}

  @override
  Future<void> refreshBooking(String requestId, {String? workerId}) async {}

  @override
  Stream<Map<String, dynamic>?> watchRequest(String requestId) =>
      Stream.value(request);

  @override
  Stream<Map<String, dynamic>?> watchReview(String requestId) =>
      Stream.value(review);

  @override
  Stream<Map<String, dynamic>?> watchWorker(String workerId) =>
      Stream.value(worker);
}
