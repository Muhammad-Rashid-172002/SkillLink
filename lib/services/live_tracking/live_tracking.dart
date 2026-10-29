import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:skill_link/services/live_tracking/tracking_math.dart';

export 'package:skill_link/services/live_tracking/tracking_math.dart';

/// A point on the map.
@immutable
class TrackingPoint {
  const TrackingPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  static TrackingPoint? tryParse(Object? value) {
    if (value is GeoPoint) {
      return TrackingPoint(value.latitude, value.longitude);
    }
    if (value is! Map) return null;
    final lat = value['latitude'] ?? value['lat'];
    final lng = value['longitude'] ?? value['lng'];
    if (lat is! num || lng is! num) return null;
    final point = TrackingPoint(lat.toDouble(), lng.toDouble());
    return point.isValid ? point : null;
  }

  /// Great-circle distance in metres (haversine). Used only to describe how
  /// far away someone is and to throttle GPS writes — never as an ETA.
  double distanceTo(TrackingPoint other) {
    const earthRadius = 6371000.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(other.latitude - latitude);
    final dLng = rad(other.longitude - longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(latitude)) *
            math.cos(rad(other.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  bool operator ==(Object other) =>
      other is TrackingPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Road route and ETA calculated server-side by Google Routes API
/// (`computeJobRoute` Cloud Function).
@immutable
class TrackingRoute {
  const TrackingRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    this.calculatedAt,
  });

  final int distanceMeters;
  final int durationSeconds;
  final List<TrackingPoint> polyline;
  final DateTime? calculatedAt;

  int get etaMinutes => math.max(1, (durationSeconds / 60).ceil());

  static TrackingRoute? tryParse(Object? value) {
    if (value is! Map) return null;
    final duration = value['durationSeconds'];
    final distance = value['distanceMeters'];
    if (duration is! num || distance is! num || duration <= 0) return null;
    final encoded = value['encodedPolyline'];
    return TrackingRoute(
      distanceMeters: distance.round(),
      durationSeconds: duration.round(),
      polyline: encoded is String
          ? [
              for (final (lat, lng) in decodePolyline(encoded))
                TrackingPoint(lat, lng),
            ]
          : const [],
      calculatedAt: trackingDate(value['calculatedAt']),
    );
  }
}

/// Snapshot of `live_tracking/{requestId}`.
@immutable
class LiveTrackingSnapshot {
  const LiveTrackingSnapshot({
    required this.isActive,
    this.workerLocation,
    this.workerUpdatedAt,
    this.heading,
    this.route,
  });

  const LiveTrackingSnapshot.empty()
    : isActive = false,
      workerLocation = null,
      workerUpdatedAt = null,
      heading = null,
      route = null;

  factory LiveTrackingSnapshot.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const LiveTrackingSnapshot.empty();
    final location = data['workerLocation'];
    final heading = location is Map ? location['heading'] : null;
    return LiveTrackingSnapshot(
      isActive: data['isActive'] == true,
      workerLocation: TrackingPoint.tryParse(location),
      workerUpdatedAt:
          trackingDate(location is Map ? location['updatedAt'] : null) ??
          trackingDate(data['workerLocationUpdatedAt']),
      heading: heading is num ? heading.toDouble() : null,
      route: TrackingRoute.tryParse(data['route']),
    );
  }

  final bool isActive;
  final TrackingPoint? workerLocation;
  final DateTime? workerUpdatedAt;
  final double? heading;
  final TrackingRoute? route;

  /// A location older than this is shown as "last seen", not live.
  static const Duration staleAfter = Duration(minutes: 2);

  bool isStale(DateTime now) =>
      workerUpdatedAt == null || now.difference(workerUpdatedAt!) > staleAfter;
}

DateTime? trackingDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Customer-facing ETA sentence. Never invents a time from straight-line
/// distance: without a road route it says so.
String describeArrival(LiveTrackingSnapshot tracking, {required DateTime now}) {
  final route = tracking.route;
  if (tracking.workerLocation == null) {
    return 'Your worker hasn’t shared their location yet. You’ll see them on '
        'the map as soon as they start travelling.';
  }
  if (tracking.isStale(now)) {
    return 'Your worker’s location hasn’t updated for a few minutes. They may '
        'have a weak signal — you can message or call them.';
  }
  if (route == null) {
    return 'Your worker is on the way. We’re still calculating the arrival '
        'time.';
  }
  final minutes = route.etaMinutes;
  return 'Your worker is on the way and is expected to arrive in '
      'approximately $minutes ${minutes == 1 ? 'minute' : 'minutes'}.';
}

/// Decides whether a new GPS fix is worth a Firestore write (battery and
/// write-cost control). Pure so it can be unit tested.
bool shouldPublishLocation({
  required TrackingPoint next,
  required TrackingPoint? last,
  required DateTime now,
  required DateTime? lastPublishedAt,
  double minMoveMeters = 20,
  Duration minInterval = const Duration(seconds: 8),
  Duration heartbeat = const Duration(seconds: 45),
}) {
  if (last == null || lastPublishedAt == null) return true;
  final elapsed = now.difference(lastPublishedAt);
  if (elapsed < minInterval) return false;
  if (elapsed >= heartbeat) return true;
  return next.distanceTo(last) >= minMoveMeters;
}

/// Writes the assigned worker's position to `live_tracking/{requestId}`.
/// Security rules only accept it from the assigned worker of an active job.
class LiveTrackingPublisher {
  LiveTrackingPublisher({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  TrackingPoint? _lastPoint;
  DateTime? _lastPublishedAt;
  DateTime? _lastRouteAt;

  /// Minimum time between server route (ETA) recalculations.
  static const Duration routeInterval = Duration(seconds: 45);

  Future<bool> publish({
    required String requestId,
    required String customerId,
    required String workerId,
    required TrackingPoint point,
    double? heading,
    double? speed,
    double? accuracy,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    if (!shouldPublishLocation(
      next: point,
      last: _lastPoint,
      now: clock,
      lastPublishedAt: _lastPublishedAt,
    )) {
      return false;
    }
    await _firestore.collection('live_tracking').doc(requestId).set({
      'requestId': requestId,
      'customerId': customerId,
      'workerId': workerId,
      'isActive': true,
      'workerLocation': {
        'latitude': point.latitude,
        'longitude': point.longitude,
        'heading': heading != null && heading.isFinite ? heading : null,
        'speed': speed != null && speed.isFinite ? speed : null,
        'accuracy': accuracy != null && accuracy.isFinite ? accuracy : null,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'workerLocationUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _lastPoint = point;
    _lastPublishedAt = clock;

    if (_lastRouteAt == null ||
        clock.difference(_lastRouteAt!) >= routeInterval) {
      _lastRouteAt = clock;
      unawaited(refreshRoute(requestId));
    }
    return true;
  }

  /// Asks the server to recalculate the road route + ETA (Google Routes
  /// API). Failures are non-fatal: the customer sees a clear fallback.
  Future<void> refreshRoute(String requestId) async {
    try {
      await _functions
          .httpsCallable('computeJobRoute')
          .call(<String, dynamic>{'requestId': requestId})
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      debugPrint('Route refresh skipped: $error');
    }
  }

  void reset() {
    _lastPoint = null;
    _lastPublishedAt = null;
    _lastRouteAt = null;
  }
}
