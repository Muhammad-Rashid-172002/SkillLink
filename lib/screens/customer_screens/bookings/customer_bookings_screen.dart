import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/RateWorkerScreen.dart';
import 'package:skill_link/screens/customer_screens/customer_my_request_scree/request_tracking_screen.dart';

import 'booking_components.dart';
import 'booking_detail_screen.dart';
import 'booking_models.dart';
import 'booking_repository.dart';
import 'booking_status.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({
    super.key,
    this.embedded = false,
    this.dataSource,
    this.onOpenBooking,
    this.onRateBooking,
  });

  final bool embedded;
  final CustomerBookingsDataSource? dataSource;
  final ValueChanged<CustomerBooking>? onOpenBooking;
  final ValueChanged<CustomerBooking>? onRateBooking;

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  late final CustomerBookingsDataSource _dataSource;
  late Stream<List<CustomerBooking>> _bookingsStream;
  BookingGroup _selectedGroup = BookingGroup.active;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? FirebaseCustomerBookingsRepository();
    _bookingsStream = _dataSource.watchBookings();
  }

  @override
  Widget build(BuildContext context) {
    if (_dataSource.customerId.isEmpty) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: ErrorState(
              title: 'Session unavailable',
              message: 'Please sign in again to view your bookings.',
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Bookings'),
      ),
      body: SafeArea(
        top: false,
        bottom: !widget.embedded,
        child: StreamBuilder<List<CustomerBooking>>(
          stream: _bookingsStream,
          builder: (context, snapshot) {
            final loading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;
            if (loading) return _loading();
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(SkillNovaSpacing.lg),
                  child: ErrorState(
                    title: 'Bookings unavailable',
                    message: 'Your bookings could not be loaded right now.',
                    actionLabel: 'Try again',
                    onAction: _resetStream,
                  ),
                ),
              );
            }
            final all = snapshot.data ?? const [];
            final visible = all
                .where((booking) => booking.status.group == _selectedGroup)
                .toList(growable: false);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                key: const PageStorageKey('customer-bookings-v2'),
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
                              Text(
                                'Your service journey',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: SkillNovaSpacing.xs),
                              Text(
                                'Clear updates from request to completion.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: SkillNovaSpacing.lg),
                              _groupControl(all),
                              const SizedBox(height: SkillNovaSpacing.lg),
                              if (visible.isEmpty)
                                BookingEmptyState(group: _selectedGroup)
                              else
                                ...visible.map(
                                  (booking) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: SkillNovaSpacing.sm,
                                    ),
                                    child: BookingCard(
                                      booking: booking,
                                      onOpen: () => _openBooking(booking),
                                      onRate: () => _rateBooking(booking),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _groupControl(List<CustomerBooking> bookings) {
    final counts = {
      for (final group in BookingGroup.values)
        group: bookings
            .where((booking) => booking.status.group == group)
            .length,
    };
    return Container(
      padding: const EdgeInsets.all(SkillNovaSpacing.xxs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
      ),
      child: Row(
        children: BookingGroup.values
            .map((group) {
              final selected = group == _selectedGroup;
              final label = switch (group) {
                BookingGroup.active => 'Active',
                BookingGroup.completed => 'Completed',
                BookingGroup.cancelled => 'Cancelled',
              };
              return Expanded(
                child: Material(
                  color: selected
                      ? Theme.of(context).colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(SkillNovaRadius.small),
                  child: InkWell(
                    key: ValueKey('booking-tab-${group.name}'),
                    onTap: () => setState(() => _selectedGroup = group),
                    borderRadius: BorderRadius.circular(SkillNovaRadius.small),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SkillNovaSpacing.xxs,
                        vertical: SkillNovaSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: SkillNovaSpacing.xxs),
                          Text(
                            '${counts[group]}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _loading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: SkillNovaSpacing.sm),
          child: SkeletonCard(height: 250),
        ),
      ),
    );
  }

  Future<void> _refresh() => _dataSource.refreshBookings();

  void _resetStream() {
    setState(() => _bookingsStream = _dataSource.watchBookings());
  }

  void _openBooking(CustomerBooking booking) {
    if (widget.onOpenBooking != null) {
      widget.onOpenBooking!(booking);
      return;
    }
    final route = booking.status.semantic == BookingSemanticStatus.onTheWay
        ? RequestTrackingScreen(requestId: booking.id)
        : BookingDetailScreen(requestId: booking.id);
    Navigator.push(context, MaterialPageRoute(builder: (_) => route));
  }

  Future<void> _rateBooking(CustomerBooking booking) async {
    if (widget.onRateBooking != null) {
      widget.onRateBooking!(booking);
      return;
    }
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RateWorkerScreen(workerId: booking.workerId, requestId: booking.id),
      ),
    );
  }
}
