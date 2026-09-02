import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/RateWorkerScreen.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/request_tracking_screen.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/WorkerPublicProfileScreen.dart';

import 'booking_actions.dart';
import 'booking_components.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import 'booking_status.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({
    super.key,
    required this.requestId,
    this.dataSource,
    this.onTrack,
    this.onMessage,
    this.onCall,
    this.onViewProfile,
    this.onRate,
    this.onCancel,
    this.onSos,
  });

  final String requestId;
  final BookingDetailDataSource? dataSource;
  final VoidCallback? onTrack;
  final VoidCallback? onMessage;
  final VoidCallback? onCall;
  final VoidCallback? onViewProfile;
  final VoidCallback? onRate;
  final VoidCallback? onCancel;
  final VoidCallback? onSos;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final BookingDetailDataSource _dataSource;
  late Stream<Map<String, dynamic>?> _requestStream;
  late Stream<Map<String, dynamic>?> _reviewStream;
  final Map<String, Stream<Map<String, dynamic>?>> _workerStreams = {};
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseCustomerBookingsRepository();
    _requestStream = _dataSource.watchRequest(widget.requestId);
    _reviewStream = _dataSource.watchReview(widget.requestId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking details')),
      body: SafeArea(
        top: false,
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _requestStream,
          builder: (context, requestSnapshot) {
            final loading =
                requestSnapshot.connectionState == ConnectionState.waiting &&
                !requestSnapshot.hasData;
            if (loading) return _loading();
            if (requestSnapshot.hasError) {
              return _error('This booking could not be loaded right now.');
            }
            final request = requestSnapshot.data;
            if (request == null) {
              return _error('This booking is unavailable or was removed.');
            }
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
                  builder: (context, reviewSnapshot) {
                    final booking = CustomerBooking(
                      id: widget.requestId,
                      data: request,
                      worker: workerSnapshot.data,
                      review: reviewSnapshot.data,
                    );
                    return _content(booking);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _content(CustomerBooking booking) {
    final status = booking.status;
    return RefreshIndicator(
      onRefresh: () => _dataSource.refreshBooking(
        widget.requestId,
        workerId: booking.workerId,
      ),
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
                      _statusHeader(booking),
                      const SizedBox(height: SkillNovaSpacing.md),
                      BookingDetailSection(
                        title: 'Status timeline',
                        icon: Icons.timeline_rounded,
                        child: BookingStatusTimeline(status: status),
                      ),
                      const SizedBox(height: SkillNovaSpacing.md),
                      if (booking.workerId.isNotEmpty)
                        BookingWorkerCard(
                          booking: booking,
                          showProfileAction:
                              status.group != BookingGroup.cancelled,
                          showCommunicationActions:
                              status.group == BookingGroup.active,
                          onViewProfile: () => _viewProfile(booking),
                          onMessage: () => _message(booking),
                          onCall: booking.workerPhone.isEmpty
                              ? null
                              : () => _call(booking),
                        )
                      else
                        _waitingProfessional(status),
                      const SizedBox(height: SkillNovaSpacing.md),
                      _serviceDetails(booking),
                      if (booking.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: SkillNovaSpacing.md),
                        _requestImages(booking.imageUrls),
                      ],
                      if (booking.location.isNotEmpty ||
                          booking.customerCoordinate != null) ...[
                        const SizedBox(height: SkillNovaSpacing.md),
                        _location(booking),
                      ],
                      if (status.canUseSafety &&
                          booking.workerId.isNotEmpty) ...[
                        const SizedBox(height: SkillNovaSpacing.md),
                        _safety(booking),
                      ],
                      const SizedBox(height: SkillNovaSpacing.lg),
                      _stateActions(booking),
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

  Widget _statusHeader(CustomerBooking booking) {
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
          Text(booking.service, style: theme.textTheme.headlineSmall),
          if (booking.createdAt != null) ...[
            const SizedBox(height: SkillNovaSpacing.xs),
            Text(
              'Requested ${bookingDateLabel(booking.createdAt, includeTime: true)}',
              style: theme.textTheme.bodyMedium,
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

  Widget _waitingProfessional(BookingStatusPresentation status) {
    return BookingDetailSection(
      title: 'Professional',
      icon: Icons.person_search_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, color: status.color),
          const SizedBox(width: SkillNovaSpacing.sm),
          Expanded(child: Text(status.description)),
        ],
      ),
    );
  }

  Widget _serviceDetails(CustomerBooking booking) {
    return BookingDetailSection(
      title: 'Service details',
      icon: Icons.home_repair_service_outlined,
      child: Column(
        children: [
          BookingDetailRow(
            label: 'Service',
            value: booking.service,
            icon: Icons.category_outlined,
          ),
          if (booking.description.isNotEmpty)
            BookingDetailRow(
              label: 'Description',
              value: booking.description,
              icon: Icons.notes_rounded,
            ),
          if (booking.urgency.isNotEmpty)
            BookingDetailRow(
              label: 'Urgency',
              value: booking.urgency,
              icon: Icons.bolt_outlined,
            ),
          if (booking.budget.isNotEmpty)
            BookingDetailRow(
              label: 'Posted budget',
              value: formatPostedBudget(booking.budget),
              icon: Icons.payments_outlined,
            ),
          if (booking.notes.isNotEmpty)
            BookingDetailRow(
              label: 'Notes',
              value: booking.notes,
              icon: Icons.sticky_note_2_outlined,
            ),
          if (booking.status.group == BookingGroup.cancelled &&
              booking.cancellationReason.isNotEmpty)
            BookingDetailRow(
              label: 'Cancellation reason',
              value: booking.cancellationReason,
              icon: Icons.info_outline_rounded,
            ),
        ],
      ),
    );
  }

  Widget _requestImages(List<String> images) {
    return BookingDetailSection(
      title: 'Request photos',
      icon: Icons.photo_library_outlined,
      child: SizedBox(
        height: 104,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: SkillNovaSpacing.sm),
          itemBuilder: (context, index) {
            final url = images[index];
            return InkWell(
              onTap: () => _previewImage(url),
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
                child: SizedBox(
                  width: 104,
                  child: Image.network(
                    url,
                    key: ValueKey('booking-detail-image-$index'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _location(CustomerBooking booking) {
    final coordinate = booking.customerCoordinate;
    return BookingDetailSection(
      title: 'Service location',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booking.location.isNotEmpty)
            Text(
              booking.location,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (coordinate != null) ...[
            if (booking.location.isNotEmpty)
              const SizedBox(height: SkillNovaSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              child: SizedBox(
                height: 190,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(coordinate.latitude, coordinate.longitude),
                    zoom: 14,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('customer-location'),
                      position: LatLng(
                        coordinate.latitude,
                        coordinate.longitude,
                      ),
                      infoWindow: const InfoWindow(title: 'Service location'),
                    ),
                  },
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
            ),
          ],
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

  Widget _stateActions(CustomerBooking booking) {
    final status = booking.status;
    if (status.group == BookingGroup.completed) {
      return SizedBox(
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
      );
    }
    if (status.semantic == BookingSemanticStatus.onTheWay) {
      return SizedBox(
        width: double.infinity,
        child: PrimaryButton(
          label: 'Track service',
          icon: Icons.map_outlined,
          onPressed: () => _track(booking),
        ),
      );
    }
    if (status.canCancel) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _cancelling ? null : () => _cancel(booking),
          icon: const Icon(Icons.cancel_outlined),
          label: Text(_cancelling ? 'Cancelling...' : 'Cancel request'),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _cancel(CustomerBooking booking) async {
    if (widget.onCancel != null) {
      widget.onCancel!();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
          'This pre-service request will no longer be active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await _dataSource.cancelPreServiceRequest(booking.id);
    } catch (error) {
      if (mounted) {
        showBookingMessage(
          context,
          error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  void _track(CustomerBooking booking) {
    if (widget.onTrack != null) return widget.onTrack!();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestTrackingScreen(requestId: booking.id),
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

  Future<void> _sos(CustomerBooking booking) async {
    if (widget.onSos != null) return widget.onSos!();
    await sendBookingSos(context, booking);
  }

  void _previewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox(
              height: 240,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loading() => const Center(child: CircularProgressIndicator());

  Widget _error(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SkillNovaSpacing.lg),
        child: ErrorState(
          title: 'Booking unavailable',
          message: message,
          actionLabel: 'Try again',
          onAction: () => setState(() {
            _requestStream = _dataSource.watchRequest(widget.requestId);
            _reviewStream = _dataSource.watchReview(widget.requestId);
          }),
        ),
      ),
    );
  }
}
