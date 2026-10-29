import 'package:flutter/material.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_actions.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_components.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_models.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_repository.dart';
import 'package:skill_link/screens/customer_screens/bookings/booking_status.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/RateWorkerScreen.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';
import 'package:skill_link/screens/customer_screens/tracking/live_tracking_panel.dart';
import 'package:skill_link/services/live_tracking/live_tracking.dart';

class RequestTrackingScreen extends StatefulWidget {
  const RequestTrackingScreen({
    super.key,
    required this.requestId,
    this.dataSource,
    this.onMessage,
    this.onCall,
    this.onViewProfile,
    this.onSos,
    this.onRate,
    this.trackingStream,
  });

  final String requestId;
  final BookingDetailDataSource? dataSource;

  /// Live position + route for this job. Defaults to
  /// `live_tracking/{requestId}` in Firestore.
  final Stream<LiveTrackingSnapshot>? trackingStream;
  final VoidCallback? onMessage;
  final VoidCallback? onCall;
  final VoidCallback? onViewProfile;
  final VoidCallback? onSos;
  final VoidCallback? onRate;

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen> {
  late final BookingDetailDataSource _dataSource;
  late Stream<Map<String, dynamic>?> _requestStream;
  late Stream<Map<String, dynamic>?> _reviewStream;
  final Map<String, Stream<Map<String, dynamic>?>> _workerStreams = {};
  late final Stream<LiveTrackingSnapshot> _trackingStream;

  @override
  void initState() {
    super.initState();
    _trackingStream =
        widget.trackingStream ??
        (widget.dataSource != null
            // Injected data sources (tests, previews) have no Firestore.
            ? const Stream<LiveTrackingSnapshot>.empty()
            : FirebaseFirestore.instance
                  .collection('live_tracking')
                  .doc(widget.requestId)
                  .snapshots()
                  .map((doc) => LiveTrackingSnapshot.fromMap(doc.data()))
                  .handleError((Object _) {}));
    _dataSource = widget.dataSource ?? FirebaseCustomerBookingsRepository();
    _requestStream = _dataSource.watchRequest(widget.requestId);
    _reviewStream = _dataSource.watchReview(widget.requestId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request tracking')),
      body: SafeArea(
        top: false,
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _requestStream,
          builder: (context, requestSnapshot) {
            final loading =
                requestSnapshot.connectionState == ConnectionState.waiting &&
                !requestSnapshot.hasData;
            if (loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (requestSnapshot.hasError) {
              return _error(
                'Tracking information could not be loaded right now.',
              );
            }
            final request = requestSnapshot.data;
            if (request == null) return _error('This request is unavailable.');
            final workerId = bookingText(request, const ['workerId']);
            final workerStream = workerId.isEmpty
                ? null
                : _workerStreams.putIfAbsent(
                    workerId,
                    () => _dataSource.watchWorker(workerId),
                  );
            return StreamBuilder<Map<String, dynamic>?>(
              stream: workerStream,
              builder: (context, workerSnapshot) {
                return StreamBuilder<Map<String, dynamic>?>(
                  stream: _reviewStream,
                  builder: (context, reviewSnapshot) => _content(
                    CustomerBooking(
                      id: widget.requestId,
                      data: request,
                      worker: workerSnapshot.data,
                      review: reviewSnapshot.data,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _content(CustomerBooking booking) {
    return RefreshIndicator(
      onRefresh: () =>
          _dataSource.refreshBooking(booking.id, workerId: booking.workerId),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SkillNovaSpacing.md,
                    SkillNovaSpacing.xs,
                    SkillNovaSpacing.md,
                    SkillNovaSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summary(booking),
                      const SizedBox(height: SkillNovaSpacing.md),
                      if (booking.workerId.isNotEmpty)
                        BookingWorkerCard(
                          booking: booking,
                          showProfileAction:
                              booking.status.group != BookingGroup.cancelled,
                          showCommunicationActions:
                              booking.status.group == BookingGroup.active,
                          onViewProfile: () => _viewProfile(booking),
                          onMessage: () => _message(booking),
                          onCall: booking.workerPhone.isEmpty
                              ? null
                              : () => _call(booking),
                        )
                      else
                        // Nobody assigned yet: explain what happens next
                        // instead of repeating the status line and showing an
                        // empty map.
                        const InfoBanner(
                          icon: Icons.hourglass_top_rounded,
                          title: 'What happens next',
                          message:
                              'Verified professionals nearby can see your '
                              'request. We’ll notify you as soon as one '
                              'accepts, and live tracking starts then.',
                        ),
                      if (booking.workerId.isNotEmpty) ...[
                        const SizedBox(height: SkillNovaSpacing.md),
                        LiveTrackingPanel(
                          booking: booking,
                          tracking: _trackingStream,
                        ),
                      ],
                      const SizedBox(height: SkillNovaSpacing.md),
                      BookingDetailSection(
                        title: 'Status timeline',
                        icon: Icons.timeline_rounded,
                        child: BookingStatusTimeline(status: booking.status),
                      ),
                      if (booking.status.canUseSafety &&
                          booking.workerId.isNotEmpty) ...[
                        const SizedBox(height: SkillNovaSpacing.md),
                        _safety(booking),
                      ],
                      if (booking.status.group == BookingGroup.completed) ...[
                        const SizedBox(height: SkillNovaSpacing.md),
                        _reviewAction(booking),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(CustomerBooking booking) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SkillNovaSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(booking.title, style: theme.textTheme.headlineSmall),
          if (booking.title != booking.service) ...[
            const SizedBox(height: 2),
            Text(booking.service, style: theme.textTheme.bodyMedium),
          ],
          if (booking.location.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: SkillNovaSpacing.xs),
                Expanded(child: Text(booking.location)),
              ],
            ),
          ],
          const SizedBox(height: SkillNovaSpacing.md),
          BookingStatusBadge(status: booking.status),
          const SizedBox(height: SkillNovaSpacing.sm),
          Text(booking.status.description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _safety(CustomerBooking booking) {
    return BookingDetailSection(
      title: 'Safety & emergency',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Use SOS only if you feel unsafe or need urgent help.'),
          const SizedBox(height: SkillNovaSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _sos(booking),
            icon: const Icon(Icons.sos_rounded),
            label: const Text('Safety support'),
          ),
        ],
      ),
    );
  }

  Widget _reviewAction(CustomerBooking booking) {
    return BookingDetailSection(
      title: 'Your review',
      icon: Icons.star_outline_rounded,
      child: SizedBox(
        width: double.infinity,
        child: booking.hasReview
            ? OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  booking.submittedRating == null
                      ? 'Review submitted'
                      : 'Rated ${booking.submittedRating!.toStringAsFixed(0)} stars',
                ),
              )
            : PrimaryButton(
                label: 'Rate service',
                icon: Icons.star_outline_rounded,
                onPressed: booking.workerId.isEmpty
                    ? null
                    : () => _rate(booking),
              ),
      ),
    );
  }

  void _viewProfile(CustomerBooking booking) {
    if (widget.onViewProfile != null) return widget.onViewProfile!();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerPublicProfileScreen(workerId: booking.workerId),
      ),
    );
  }

  Future<void> _message(CustomerBooking booking) async {
    if (widget.onMessage != null) return widget.onMessage!();
    await openBookingChat(context, booking);
  }

  Future<void> _call(CustomerBooking booking) async {
    if (widget.onCall != null) return widget.onCall!();
    await callBookingProfessional(context, booking.workerPhone);
  }

  Future<void> _sos(CustomerBooking booking) async {
    if (widget.onSos != null) return widget.onSos!();
    await sendBookingSos(context, booking);
  }

  Future<void> _rate(CustomerBooking booking) async {
    if (widget.onRate != null) return widget.onRate!();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RateWorkerScreen(workerId: booking.workerId, requestId: booking.id),
      ),
    );
  }

  Widget _error(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SkillNovaSpacing.lg),
        child: ErrorState(
          title: 'Tracking unavailable',
          message: message,
          actionLabel: 'Try again',
          onAction: () => setState(
            () => _requestStream = _dataSource.watchRequest(widget.requestId),
          ),
        ),
      ),
    );
  }
}
