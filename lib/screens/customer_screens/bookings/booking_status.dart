import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';

enum BookingGroup { active, completed, cancelled }

enum BookingSemanticStatus {
  searching,
  waitingWorker,
  accepted,
  onTheWay,
  inProgress,
  completed,
  cancelled,
  unknown,
}

class BookingStatusPresentation {
  const BookingStatusPresentation({
    required this.semantic,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.group,
    required this.timelineStage,
    required this.primaryActionLabel,
  });

  final BookingSemanticStatus semantic;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final BookingGroup group;
  final int timelineStage;
  final String primaryActionLabel;

  bool get canCancel =>
      semantic == BookingSemanticStatus.searching ||
      semantic == BookingSemanticStatus.waitingWorker;

  bool get hasAssignedProfessional => switch (semantic) {
    BookingSemanticStatus.accepted ||
    BookingSemanticStatus.onTheWay ||
    BookingSemanticStatus.inProgress ||
    BookingSemanticStatus.completed => true,
    _ => false,
  };

  bool get canUseSafety =>
      semantic == BookingSemanticStatus.accepted ||
      semantic == BookingSemanticStatus.onTheWay ||
      semantic == BookingSemanticStatus.inProgress;
}

BookingStatusPresentation bookingStatusOf(dynamic rawStatus) {
  final value = normalizeBookingStatus(rawStatus);
  return switch (value) {
    'searching' || 'pending' || 'requested' => const BookingStatusPresentation(
      semantic: BookingSemanticStatus.searching,
      label: 'Finding a professional',
      description: 'Your request is open to eligible professionals.',
      icon: Icons.person_search_outlined,
      color: SkillNovaColors.primary,
      group: BookingGroup.active,
      timelineStage: 0,
      primaryActionLabel: 'View request',
    ),
    'waiting_worker' => const BookingStatusPresentation(
      semantic: BookingSemanticStatus.waitingWorker,
      label: 'Waiting for professional',
      description: 'Your selected professional has been notified.',
      icon: Icons.hourglass_top_rounded,
      color: SkillNovaColors.warning,
      group: BookingGroup.active,
      timelineStage: 0,
      primaryActionLabel: 'View request',
    ),
    'accepted' => const BookingStatusPresentation(
      semantic: BookingSemanticStatus.accepted,
      label: 'Professional assigned',
      description: 'A professional has accepted your request.',
      icon: Icons.verified_outlined,
      color: SkillNovaColors.primary,
      group: BookingGroup.active,
      timelineStage: 1,
      primaryActionLabel: 'View booking',
    ),
    'on_the_way' || 'ontheway' => const BookingStatusPresentation(
      semantic: BookingSemanticStatus.onTheWay,
      label: 'Professional on the way',
      description: 'Your professional is travelling to the service location.',
      icon: Icons.directions_car_filled_outlined,
      color: SkillNovaColors.accent,
      group: BookingGroup.active,
      timelineStage: 2,
      primaryActionLabel: 'Track service',
    ),
    'in_progress' || 'started' => const BookingStatusPresentation(
      semantic: BookingSemanticStatus.inProgress,
      label: 'Service in progress',
      description: 'The professional has started the service.',
      icon: Icons.handyman_outlined,
      color: SkillNovaColors.warning,
      group: BookingGroup.active,
      timelineStage: 3,
      primaryActionLabel: 'View service',
    ),
    'completed' => const BookingStatusPresentation(
      semantic: BookingSemanticStatus.completed,
      label: 'Completed',
      description: 'The professional marked this service as completed.',
      icon: Icons.task_alt_rounded,
      color: SkillNovaColors.success,
      group: BookingGroup.completed,
      timelineStage: 4,
      primaryActionLabel: 'View booking',
    ),
    'cancelled' || 'canceled' || 'rejected' => const BookingStatusPresentation(
      semantic: BookingSemanticStatus.cancelled,
      label: 'Cancelled',
      description: 'This request is no longer active.',
      icon: Icons.cancel_outlined,
      color: SkillNovaColors.error,
      group: BookingGroup.cancelled,
      timelineStage: 0,
      primaryActionLabel: 'View booking',
    ),
    _ => const BookingStatusPresentation(
      semantic: BookingSemanticStatus.unknown,
      label: 'Request received',
      description: 'Open the request to see its current details.',
      icon: Icons.receipt_long_outlined,
      color: SkillNovaColors.primary,
      group: BookingGroup.active,
      timelineStage: 0,
      primaryActionLabel: 'View request',
    ),
  };
}

String normalizeBookingStatus(dynamic rawStatus) {
  return rawStatus
          ?.toString()
          .trim()
          .toLowerCase()
          .replaceAll('-', '_')
          .replaceAll(RegExp(r'\s+'), '_') ??
      '';
}

bool canCancelBookingStatus(dynamic rawStatus) =>
    bookingStatusOf(rawStatus).canCancel;
