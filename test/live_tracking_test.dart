import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/services/live_tracking/live_tracking.dart';

void main() {
  test('decodes the Google reference polyline', () {
    final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(points, hasLength(3));
    expect(points[0].$1, closeTo(38.5, 1e-6));
    expect(points[0].$2, closeTo(-120.2, 1e-6));
    expect(points[1].$1, closeTo(40.7, 1e-6));
    expect(points[1].$2, closeTo(-120.95, 1e-6));
    expect(points[2].$1, closeTo(43.252, 1e-6));
    expect(points[2].$2, closeTo(-126.453, 1e-6));
  });

  test('parses a tracking document and rejects invalid coordinates', () {
    final snapshot = LiveTrackingSnapshot.fromMap({
      'isActive': true,
      'workerLocation': {
        'latitude': 33.6938,
        'longitude': 73.0652,
        'heading': 90,
        'updatedAt': DateTime(2026, 10, 30, 12),
      },
      'route': {
        'distanceMeters': 4200,
        'durationSeconds': 540,
        'encodedPolyline': '_p~iF~ps|U_ulLnnqC',
      },
    });
    expect(snapshot.isActive, isTrue);
    expect(snapshot.workerLocation, const TrackingPoint(33.6938, 73.0652));
    expect(snapshot.heading, 90);
    expect(snapshot.route!.etaMinutes, 9);
    expect(snapshot.route!.polyline, hasLength(2));

    final invalid = LiveTrackingSnapshot.fromMap({
      'workerLocation': {'latitude': 120, 'longitude': 73},
      'route': {'distanceMeters': 10, 'durationSeconds': 0},
    });
    expect(invalid.workerLocation, isNull);
    expect(invalid.route, isNull, reason: 'zero-duration route is unusable');
  });

  group('describeArrival never fakes an ETA', () {
    final now = DateTime(2026, 10, 30, 12, 0, 30);
    const worker = TrackingPoint(33.6938, 73.0652);

    test('route available -> minutes from Google Routes', () {
      final text = describeArrival(
        LiveTrackingSnapshot(
          isActive: true,
          workerLocation: worker,
          workerUpdatedAt: DateTime(2026, 10, 30, 12),
          route: const TrackingRoute(
            distanceMeters: 3000,
            durationSeconds: 61,
            polyline: [],
          ),
        ),
        now: now,
      );
      expect(
        text,
        'Your worker is on the way and is expected to arrive in '
        'approximately 2 minutes.',
      );
    });

    test('no route -> says it is still calculating (no straight-line ETA)', () {
      final text = describeArrival(
        LiveTrackingSnapshot(
          isActive: true,
          workerLocation: worker,
          workerUpdatedAt: DateTime(2026, 10, 30, 12),
        ),
        now: now,
      );
      expect(text, contains('still calculating'));
      expect(text, isNot(contains('minute')));
    });

    test('stale location is called out', () {
      final text = describeArrival(
        LiveTrackingSnapshot(
          isActive: true,
          workerLocation: worker,
          workerUpdatedAt: DateTime(2026, 10, 30, 11, 50),
        ),
        now: now,
      );
      expect(text, contains('hasn’t updated'));
    });

    test('no location yet', () {
      expect(
        describeArrival(const LiveTrackingSnapshot.empty(), now: now),
        contains('hasn’t shared their location yet'),
      );
    });
  });

  test('GPS writes are throttled by time and distance', () {
    final t0 = DateTime(2026, 10, 30, 12);
    const a = TrackingPoint(33.6938, 73.0652);
    const near = TrackingPoint(33.69385, 73.06525); // ~7 m
    const far = TrackingPoint(33.6960, 73.0652); // ~245 m
    expect(
      shouldPublishLocation(
        next: a,
        last: null,
        now: t0,
        lastPublishedAt: null,
      ),
      isTrue,
    );
    expect(
      shouldPublishLocation(
        next: far,
        last: a,
        now: t0.add(const Duration(seconds: 3)),
        lastPublishedAt: t0,
      ),
      isFalse,
      reason: 'never faster than the minimum interval',
    );
    expect(
      shouldPublishLocation(
        next: near,
        last: a,
        now: t0.add(const Duration(seconds: 20)),
        lastPublishedAt: t0,
      ),
      isFalse,
      reason: 'tiny movement is skipped',
    );
    expect(
      shouldPublishLocation(
        next: far,
        last: a,
        now: t0.add(const Duration(seconds: 20)),
        lastPublishedAt: t0,
      ),
      isTrue,
    );
    expect(
      shouldPublishLocation(
        next: near,
        last: a,
        now: t0.add(const Duration(seconds: 50)),
        lastPublishedAt: t0,
      ),
      isTrue,
      reason: 'heartbeat keeps the customer view fresh',
    );
  });

  test('distance formatting', () {
    expect(formatTrackingDistance(640), '640 m');
    expect(formatTrackingDistance(4230), '4.2 km');
    expect(formatTrackingDistance(15600), '16 km');
  });
}
