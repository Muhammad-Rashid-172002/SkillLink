import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';

import 'booking_models.dart';
import 'booking_status.dart';

class BookingStatusBadge extends StatelessWidget {
  const BookingStatusBadge({super.key, required this.status});

  final BookingStatusPresentation status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SkillNovaSpacing.sm,
        vertical: SkillNovaSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 16),
          const SizedBox(width: SkillNovaSpacing.xxs),
          Flexible(
            child: Text(
              status.label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: status.color),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingProgressIndicator extends StatelessWidget {
  const BookingProgressIndicator({super.key, required this.status});

  final BookingStatusPresentation status;

  @override
  Widget build(BuildContext context) {
    if (status.group == BookingGroup.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel_rounded, color: status.color, size: 18),
          const SizedBox(width: SkillNovaSpacing.xs),
          Expanded(
            child: Text(
              'Request closed',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: status.color),
            ),
          ),
        ],
      );
    }
    return Row(
      children: List.generate(5, (index) {
        final reached = index <= status.timelineStage;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
            decoration: BoxDecoration(
              color: reached
                  ? status.color
                  : Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
            ),
          ),
        );
      }),
    );
  }
}

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.onOpen,
    required this.onRate,
  });

  final CustomerBooking booking;
  final VoidCallback onOpen;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = booking.imageUrls.firstOrNull;
    final status = booking.status;
    final date = switch (status.group) {
      BookingGroup.completed => booking.completedAt ?? booking.createdAt,
      BookingGroup.cancelled => booking.cancelledAt ?? booking.createdAt,
      BookingGroup.active => booking.createdAt,
    };
    return Container(
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ServiceVisual(service: booking.service, imageUrl: image),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.service,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: SkillNovaSpacing.xxs),
                    Text(
                      bookingDateLabel(date, includeTime: true),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: BookingStatusBadge(status: status),
          ),
          const SizedBox(height: SkillNovaSpacing.sm),
          BookingProgressIndicator(status: status),
          if (booking.workerId.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            Row(
              children: [
                _BookingAvatar(
                  name: booking.workerName,
                  photoUrl: booking.workerPhoto,
                  size: 38,
                ),
                const SizedBox(width: SkillNovaSpacing.xs),
                Expanded(
                  child: Text(
                    booking.workerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ],
          if (booking.location.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.xs),
            _CompactDetail(
              icon: Icons.location_on_outlined,
              text: booking.location,
            ),
          ],
          if (booking.budget.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.xs),
            _CompactDetail(
              icon: Icons.payments_outlined,
              text: 'Posted budget: ${formatPostedBudget(booking.budget)}',
            ),
          ],
          if (status.group == BookingGroup.cancelled &&
              booking.cancellationReason.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.xs),
            _CompactDetail(
              icon: Icons.info_outline_rounded,
              text: booking.cancellationReason,
            ),
          ],
          if (status.group == BookingGroup.completed) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            _ReviewState(booking: booking),
          ],
          const SizedBox(height: SkillNovaSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label:
                  status.group == BookingGroup.completed &&
                      !booking.hasReview &&
                      booking.workerId.isNotEmpty
                  ? 'Rate service'
                  : status.primaryActionLabel,
              icon: status.group == BookingGroup.completed && !booking.hasReview
                  ? Icons.star_outline_rounded
                  : Icons.arrow_forward_rounded,
              onPressed:
                  status.group == BookingGroup.completed &&
                      !booking.hasReview &&
                      booking.workerId.isNotEmpty
                  ? onRate
                  : onOpen,
            ),
          ),
        ],
      ),
    );
  }
}

class BookingStatusTimeline extends StatelessWidget {
  const BookingStatusTimeline({super.key, required this.status});

  final BookingStatusPresentation status;

  static const _steps = [
    ('Request sent', Icons.send_outlined),
    ('Professional assigned', Icons.person_pin_circle_outlined),
    ('On the way', Icons.directions_car_filled_outlined),
    ('Service in progress', Icons.handyman_outlined),
    ('Completed', Icons.task_alt_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final cancelled = status.group == BookingGroup.cancelled;
    if (cancelled) {
      return Column(
        children: [
          _TimelineStep(
            label: 'Request sent',
            icon: Icons.send_outlined,
            reached: true,
            current: false,
            showConnector: true,
            color: status.color,
          ),
          _TimelineStep(
            label: 'Cancelled',
            icon: Icons.cancel_outlined,
            reached: true,
            current: true,
            showConnector: false,
            color: status.color,
          ),
        ],
      );
    }
    return Column(
      children: [
        for (var index = 0; index < _steps.length; index++)
          _TimelineStep(
            label: _steps[index].$1,
            icon: _steps[index].$2,
            reached: index <= status.timelineStage,
            current: index == status.timelineStage,
            showConnector: index != _steps.length - 1,
            color: status.color,
          ),
      ],
    );
  }
}

class BookingWorkerCard extends StatelessWidget {
  const BookingWorkerCard({
    super.key,
    required this.booking,
    required this.onViewProfile,
    required this.onMessage,
    required this.onCall,
    this.showProfileAction = true,
    this.showCommunicationActions = true,
  });

  final CustomerBooking booking;
  final VoidCallback onViewProfile;
  final VoidCallback onMessage;
  final VoidCallback? onCall;
  final bool showProfileAction;
  final bool showCommunicationActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _BookingAvatar(
                name: booking.workerName,
                photoUrl: booking.workerPhoto,
                size: 58,
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            booking.workerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (booking.workerVerified) ...[
                          const SizedBox(width: SkillNovaSpacing.xxs),
                          Icon(
                            Icons.verified_rounded,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      booking.workerSkill,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (booking.workerRating != null &&
                        booking.workerRating! > 0)
                      Text(
                        '★ ${booking.workerRating!.toStringAsFixed(1)}',
                        style: theme.textTheme.labelMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (showProfileAction || showCommunicationActions) ...[
            const SizedBox(height: SkillNovaSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: SkillNovaSpacing.xs,
              runSpacing: SkillNovaSpacing.xs,
              children: [
                if (showProfileAction)
                  TextButton.icon(
                    onPressed: onViewProfile,
                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                    label: const Text('View profile'),
                  ),
                if (showCommunicationActions)
                  OutlinedButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Message'),
                  ),
                if (showCommunicationActions && onCall != null)
                  IconButton.outlined(
                    tooltip: 'Call professional',
                    onPressed: onCall,
                    icon: const Icon(Icons.call_outlined),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class BookingDetailSection extends StatelessWidget {
  const BookingDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });

  final String title;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SkillNovaSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: theme.colorScheme.primary, size: 21),
                const SizedBox(width: SkillNovaSpacing.xs),
              ],
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          child,
        ],
      ),
    );
  }
}

class BookingDetailRow extends StatelessWidget {
  const BookingDetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: SkillNovaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: SkillNovaSpacing.xxs),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BookingEmptyState extends StatelessWidget {
  const BookingEmptyState({super.key, required this.group});

  final BookingGroup group;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = switch (group) {
      BookingGroup.active => (
        'No active bookings',
        'When you request a service, it will appear here.',
        Icons.calendar_today_outlined,
      ),
      BookingGroup.completed => (
        'No completed bookings',
        'Finished services will appear here.',
        Icons.task_alt_outlined,
      ),
      BookingGroup.cancelled => (
        'No cancelled bookings',
        'Cancelled requests will appear here.',
        Icons.event_busy_outlined,
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SkillNovaSpacing.xxl),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: SkillNovaSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ServiceVisual extends StatelessWidget {
  const _ServiceVisual({required this.service, this.imageUrl});

  final String service;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(
        _serviceIcon(service),
        color: Theme.of(context).colorScheme.primary,
        size: 28,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
      child: SizedBox(
        width: 64,
        height: 64,
        child: imageUrl == null || imageUrl!.isEmpty
            ? fallback
            : Image.network(
                imageUrl!,
                key: ValueKey('booking-image-$imageUrl'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _BookingAvatar extends StatelessWidget {
  const _BookingAvatar({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  final String name;
  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Text(
          initials.isEmpty ? 'SN' : initials,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: photoUrl.isEmpty
          ? KeyedSubtree(
              key: ValueKey('booking-worker-fallback-$name'),
              child: fallback,
            )
          : Image.network(
              photoUrl,
              key: ValueKey('booking-worker-image-$name'),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _CompactDetail extends StatelessWidget {
  const _CompactDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: SkillNovaSpacing.xs),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ReviewState extends StatelessWidget {
  const _ReviewState({required this.booking});

  final CustomerBooking booking;

  @override
  Widget build(BuildContext context) {
    final submitted = booking.hasReview;
    return Row(
      children: [
        Icon(
          submitted
              ? Icons.check_circle_outline_rounded
              : Icons.star_outline_rounded,
          color: submitted ? SkillNovaColors.success : SkillNovaColors.warning,
          size: 18,
        ),
        const SizedBox(width: SkillNovaSpacing.xs),
        Expanded(
          child: Text(
            submitted
                ? booking.submittedRating == null
                      ? 'Review submitted'
                      : 'Your rating: ${booking.submittedRating!.toStringAsFixed(0)} stars'
                : 'Your feedback is pending',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.icon,
    required this.reached,
    required this.current,
    required this.showConnector,
    required this.color,
  });

  final String label;
  final IconData icon;
  final bool reached;
  final bool current;
  final bool showConnector;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outlineVariant;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reached
                        ? color
                        : Theme.of(context).colorScheme.surfaceContainer,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: reached ? Colors.white : muted,
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(width: 2, color: reached ? color : muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SkillNovaSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: SkillNovaSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  if (current) ...[
                    const SizedBox(height: SkillNovaSpacing.xxs),
                    Text(
                      'Current status',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _serviceIcon(String service) {
  final value = service.toLowerCase();
  if (value.contains('electric')) return Icons.electrical_services_outlined;
  if (value.contains('plumb')) return Icons.plumbing_outlined;
  if (value.contains('clean')) return Icons.cleaning_services_outlined;
  if (value.contains('ac') || value.contains('air')) {
    return Icons.ac_unit_outlined;
  }
  if (value.contains('carpenter')) return Icons.carpenter_outlined;
  return Icons.home_repair_service_outlined;
}
