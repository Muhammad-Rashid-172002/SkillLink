import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/design_system/widgets/skillnova_map.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_components.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_models.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_status.dart';
import 'package:skill_link/services/live_tracking/live_tracking.dart';

/// Ride-hailing style live tracking for the customer: the worker's marker
/// glides to each new GPS fix, the road route and ETA come from Google Routes
/// (server-side), and every state has a plain-language explanation.
class LiveTrackingPanel extends StatefulWidget {
  const LiveTrackingPanel({
    super.key,
    required this.booking,
    required this.tracking,
    this.now,
  });

  final CustomerBooking booking;

  /// `live_tracking/{requestId}` stream (security rules: only this job's
  /// customer and worker can read it).
  final Stream<LiveTrackingSnapshot> tracking;

  /// Test clock.
  final DateTime Function()? now;

  @override
  State<LiveTrackingPanel> createState() => _LiveTrackingPanelState();
}

class _LiveTrackingPanelState extends State<LiveTrackingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..addListener(() => setState(() {}));
  late final Stream<LiveTrackingSnapshot> _stream = widget.tracking;
  GoogleMapController? _map;
  TrackingPoint? _from;
  TrackingPoint? _to;
  bool _fitted = false;
  Timer? _ticker;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    // Keeps "updated 20 s ago" honest without new data arriving.
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _glide.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _moveTo(TrackingPoint target) {
    if (_to == target) return;
    if (_to == null || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _from = target;
      _to = target;
      _glide.value = 1;
      return;
    }
    _from = _current ?? _to;
    _to = target;
    _glide.forward(from: 0);
  }

  TrackingPoint? get _current {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return to;
    final t = Curves.easeInOut.transform(_glide.value);
    return TrackingPoint(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LiveTrackingSnapshot>(
      stream: _stream,
      initialData: const LiveTrackingSnapshot.empty(),
      builder: (context, snapshot) {
        final tracking = snapshot.data ?? const LiveTrackingSnapshot.empty();
        return _content(context, tracking);
      },
    );
  }

  Widget _content(BuildContext context, LiveTrackingSnapshot tracking) {
    final booking = widget.booking;
    final theme = Theme.of(context);
    final onTheWay = booking.status.semantic == BookingSemanticStatus.onTheWay;
    final destination = booking.customerCoordinate;
    final destinationPoint = destination == null
        ? null
        : TrackingPoint(destination.latitude, destination.longitude);

    // Live position from live_tracking; older app versions wrote it on the
    // worker profile, which is kept as a read-only fallback.
    TrackingPoint? workerTarget;
    DateTime? updatedAt;
    if (onTheWay && tracking.workerLocation != null) {
      workerTarget = tracking.workerLocation;
      updatedAt = tracking.workerUpdatedAt;
    } else if (booking.workerTrackingCoordinate != null) {
      final legacy = booking.workerTrackingCoordinate!;
      workerTarget = TrackingPoint(legacy.latitude, legacy.longitude);
      updatedAt = bookingDate(booking.worker?['locationUpdatedAt']);
    }
    if (workerTarget != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveTo(workerTarget!);
      });
    }
    final workerPoint = _current ?? workerTarget;

    final markers = <Marker>{
      if (destinationPoint != null)
        Marker(
          markerId: const MarkerId('customer-location'),
          position: LatLng(
            destinationPoint.latitude,
            destinationPoint.longitude,
          ),
          infoWindow: const InfoWindow(title: 'Service location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      if (workerPoint != null)
        Marker(
          markerId: const MarkerId('worker-location'),
          position: LatLng(workerPoint.latitude, workerPoint.longitude),
          rotation: tracking.heading ?? 0,
          flat: tracking.heading != null,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: booking.workerName,
            snippet: 'Your worker',
          ),
        ),
    };
    final route = onTheWay ? tracking.route : null;
    final polylines = <Polyline>{
      if (route != null && route.polyline.length > 1)
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            for (final point in route.polyline)
              LatLng(point.latitude, point.longitude),
          ],
          width: 6,
          color: theme.colorScheme.primary,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };

    final now = _now;
    final straightLine = workerTarget != null && destinationPoint != null
        ? workerTarget.distanceTo(destinationPoint)
        : null;

    return BookingDetailSection(
      title: onTheWay ? 'Live tracking' : 'Location tracking',
      icon: Icons.map_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onTheWay) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                describeArrival(
                  LiveTrackingSnapshot(
                    isActive: tracking.isActive,
                    workerLocation: workerTarget,
                    workerUpdatedAt: updatedAt,
                    route: route,
                  ),
                  now: now,
                ),
                key: const ValueKey('tracking-eta-sentence'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: SkillNovaSpacing.sm),
            Wrap(
              spacing: SkillNovaSpacing.xs,
              runSpacing: SkillNovaSpacing.xs,
              children: [
                if (route != null)
                  _Chip(
                    icon: Icons.schedule_rounded,
                    label: 'About ${route.etaMinutes} min',
                  ),
                if (route != null)
                  _Chip(
                    icon: Icons.route_rounded,
                    label:
                        '${formatTrackingDistance(route.distanceMeters.toDouble())} by road',
                  )
                else if (straightLine != null)
                  _Chip(
                    icon: Icons.social_distance_rounded,
                    label:
                        '${formatTrackingDistance(straightLine)} away (straight line)',
                  ),
              ],
            ),
            const SizedBox(height: SkillNovaSpacing.sm),
          ],
          if (markers.isEmpty)
            const EmptyState(
              icon: Icons.location_off_outlined,
              title: 'Location unavailable',
              message:
                  'No valid service or professional coordinates are available.',
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height < 700 ? 220 : 280,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SkillNovaMap(
                        label: 'Live map',
                        latitude: (workerPoint ?? destinationPoint)?.latitude,
                        longitude: (workerPoint ?? destinationPoint)?.longitude,
                        builder: (_) => GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              (workerPoint ?? destinationPoint)!.latitude,
                              (workerPoint ?? destinationPoint)!.longitude,
                            ),
                            zoom: markers.length == 1 ? 14 : 12,
                          ),
                          markers: markers,
                          polylines: polylines,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                          zoomControlsEnabled: false,
                          compassEnabled: false,
                          onMapCreated: (controller) {
                            _map = controller;
                            _fit(markers);
                          },
                        ),
                      ),
                    ),
                    if (markers.length > 1)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Material(
                          color: theme.colorScheme.surface,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            tooltip: 'Show both on the map',
                            icon: const Icon(Icons.center_focus_strong_rounded),
                            onPressed: () => _fit(markers, force: true),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: SkillNovaSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                workerPoint == null
                    ? Icons.location_searching_rounded
                    : Icons.near_me_rounded,
                color: theme.colorScheme.primary,
                size: 19,
              ),
              const SizedBox(width: SkillNovaSpacing.xs),
              Expanded(
                child: Text(
                  workerPoint == null
                      ? (booking.status.semantic ==
                                BookingSemanticStatus.accepted
                            ? 'Live location is not available yet. Tracking '
                                  'starts when your worker taps “On my way”.'
                            : 'Live location is not available yet.')
                      : 'Professional location last updated '
                            '${_updatedLabel(updatedAt, now)}.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _updatedLabel(DateTime? at, DateTime now) {
    if (at == null) return 'recently';
    final diff = now.difference(at);
    if (diff.isNegative || diff.inSeconds < 15) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds} seconds ago';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    return bookingDateLabel(at, includeTime: true);
  }

  Future<void> _fit(Set<Marker> markers, {bool force = false}) async {
    final controller = _map;
    if (controller == null || markers.length < 2 || (_fitted && !force)) {
      return;
    }
    final points = markers.map((marker) => marker.position).toList();
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    if ((maxLat - minLat).abs() < 0.0001 && (maxLng - minLng).abs() < 0.0001) {
      return;
    }
    _fitted = true;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          56,
        ),
      );
    } catch (_) {
      _fitted = false; // Map not laid out yet; retry on the next update.
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.onPrimaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
