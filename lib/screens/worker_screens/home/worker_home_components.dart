import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';

class WorkerHomeHeader extends StatelessWidget {
  const WorkerHomeHeader({
    super.key,
    required this.worker,
    required this.onNotifications,
  });
  final WorkerHomeProfile worker;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WorkerAvatar(worker: worker),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, ${worker.firstName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                worker.skill,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (worker.verification == WorkerVerificationState.approved)
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: SkillNovaColors.success,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Identity verified',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: SkillNovaColors.success),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Notifications',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
          style: IconButton.styleFrom(minimumSize: const Size.square(48)),
        ),
      ],
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _WorkerAvatar extends StatelessWidget {
  const _WorkerAvatar({required this.worker});
  final WorkerHomeProfile worker;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 27,
      backgroundColor: colors.primary.withValues(alpha: .1),
      child: ClipOval(
        child: worker.photoUrl.isEmpty
            ? Center(
                child: Text(
                  worker.initials,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                worker.photoUrl,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    worker.initials,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class WorkerReadinessCard extends StatelessWidget {
  const WorkerReadinessCard({
    super.key,
    required this.readiness,
    this.onAction,
  });
  final WorkerReadiness readiness;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isReady = readiness.state == WorkerReadinessState.ready;
    final isBlocked =
        readiness.state == WorkerReadinessState.blocked ||
        readiness.state == WorkerReadinessState.inactive;
    final color = isReady
        ? SkillNovaColors.success
        : isBlocked
        ? Theme.of(context).colorScheme.error
        : SkillNovaColors.warning;
    return _HomeCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(SkillNovaRadius.small),
            ),
            child: Icon(
              isReady
                  ? Icons.task_alt_rounded
                  : isBlocked
                  ? Icons.block_rounded
                  : Icons.info_outline_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  readiness.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  readiness.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (onAction != null && !isReady) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onAction,
                    child: Text(
                      readiness.state == WorkerReadinessState.needsCredits
                          ? 'View lead credits'
                          : 'Review requirements',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActiveWorkerJobCard extends StatelessWidget {
  const ActiveWorkerJobCard({
    super.key,
    required this.job,
    required this.hasAdditionalJobs,
    required this.onTap,
  });
  final WorkerActiveJob job;
  final bool hasAdditionalJobs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = workerJobStatusLabel(job.status);
    final action = switch (job.status) {
      'on_the_way' => 'Continue job',
      'in_progress' => 'Continue service',
      _ => 'View job',
    };
    return _HomeCard(
      borderColor: colors.primary.withValues(alpha: .35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_history_outlined, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active job',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusPill(label: label, color: colors.primary),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            job.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _DetailLine(icon: Icons.person_outline, text: job.customerName),
          const SizedBox(height: 6),
          _DetailLine(icon: Icons.location_on_outlined, text: job.location),
          if (job.acceptedAt != null) ...[
            const SizedBox(height: 6),
            _DetailLine(
              icon: Icons.schedule_outlined,
              text: 'Accepted ${workerRelativeTime(job.acceptedAt)}',
            ),
          ],
          if (hasAdditionalJobs) ...[
            const SizedBox(height: 10),
            Text(
              'Additional active jobs are available in Jobs.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerLeadPreviewCard extends StatelessWidget {
  const WorkerLeadPreviewCard({
    super.key,
    required this.lead,
    required this.onTap,
  });
  final WorkerLeadPreview lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _HomeCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.handyman_outlined, color: colors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lead.category,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (lead.urgency.isNotEmpty)
                _StatusPill(
                  label: lead.urgency,
                  color: SkillNovaColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailLine(icon: Icons.location_on_outlined, text: lead.location),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              if (lead.budget.isNotEmpty)
                Text(
                  'Customer posted budget: ${formatWorkerBudget(lead.budget)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              if (lead.distanceKm != null)
                Text(
                  '${formatWorkerDistance(lead.distanceKm!)} away',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              if (lead.createdAt != null)
                Text(
                  workerRelativeTime(lead.createdAt),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class LeadCreditCard extends StatelessWidget {
  const LeadCreditCard({super.key, required this.credits, required this.onTap});
  final int credits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _HomeCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.bolt_rounded, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lead credits',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '$credits available',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: credits == 0
                        ? SkillNovaColors.warning
                        : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Credits are used when accepting eligible leads.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('View credits')),
        ],
      ),
    );
  }
}

class VerificationSummaryCard extends StatelessWidget {
  const VerificationSummaryCard({
    super.key,
    required this.worker,
    required this.onTap,
  });
  final WorkerHomeProfile worker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = switch (worker.verification) {
      WorkerVerificationState.approved => (
        'Profile ready',
        'Your profile is complete and identity is approved.',
        Icons.verified_user_outlined,
      ),
      WorkerVerificationState.pending => (
        'Verification under review',
        'SkillNova is reviewing your submitted identity documents.',
        Icons.hourglass_top_rounded,
      ),
      WorkerVerificationState.rejected => (
        'Verification needs attention',
        'Review the requested changes and resubmit your documents.',
        Icons.error_outline_rounded,
      ),
      WorkerVerificationState.notStarted => (
        'Complete verification',
        'Submit the required identity documents to unlock job acceptance.',
        Icons.shield_outlined,
      ),
    };
    return _HomeCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  worker.profileCompleted
                      ? message
                      : 'Complete the required worker profile before verification.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class WorkerPerformanceSummary extends StatelessWidget {
  const WorkerPerformanceSummary({super.key, required this.worker});
  final WorkerHomeProfile worker;

  @override
  Widget build(BuildContext context) {
    final values = <(String, String)>[
      if (worker.rating != null) ('Rating', worker.rating!.toStringAsFixed(1)),
      if (worker.reviewCount != null) ('Reviews', '${worker.reviewCount}'),
    ];
    if (values.isEmpty) return const SizedBox.shrink();
    return _HomeCard(
      child: Row(
        children: values
            .map(
              (value) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Text(
                        value.$2,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value.$1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class WorkerQuickActions extends StatelessWidget {
  const WorkerQuickActions({
    super.key,
    required this.onLeads,
    required this.onJobs,
    required this.onMessages,
    required this.onProfile,
  });
  final VoidCallback onLeads;
  final VoidCallback onJobs;
  final VoidCallback onMessages;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.explore_outlined, 'Leads', onLeads),
      (Icons.work_outline_rounded, 'Jobs', onJobs),
      (Icons.chat_bubble_outline_rounded, 'Messages', onMessages),
      (Icons.person_outline_rounded, 'Profile', onProfile),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions
          .map(
            (action) => ActionChip(
              avatar: Icon(action.$1, size: 18),
              label: Text(action.$2),
              onPressed: action.$3,
            ),
          )
          .toList(growable: false),
    );
  }
}

class WorkerSectionHeader extends StatelessWidget {
  const WorkerSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (actionLabel != null)
        TextButton(onPressed: onAction, child: Text(actionLabel!)),
    ],
  );
}

class WorkerHomeEmptyCard extends StatelessWidget {
  const WorkerHomeEmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => _HomeCard(
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(message, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class WorkerHomeErrorState extends StatelessWidget {
  const WorkerHomeErrorState({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            'Dashboard unavailable',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'We could not load your worker dashboard. Check your connection and try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 6),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child, this.onTap, this.borderColor});
  final Widget child;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      child: child,
    );
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        side: BorderSide(color: borderColor ?? colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

String workerJobStatusLabel(String value) => switch (value) {
  'accepted' => 'Accepted',
  'on_the_way' => 'On the way',
  'in_progress' => 'In progress',
  _ => value.replaceAll('_', ' '),
};

String formatWorkerBudget(String value) {
  final text = value.trim();
  if (text.toLowerCase().startsWith('rs')) return text;
  return 'Rs. $text';
}

String formatWorkerDistance(double value) =>
    value < 10 ? '${value.toStringAsFixed(1)} km' : '${value.round()} km';

String workerRelativeTime(DateTime? value) {
  if (value == null) return '';
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}
