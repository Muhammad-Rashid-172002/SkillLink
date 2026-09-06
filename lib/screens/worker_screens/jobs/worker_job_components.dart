import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';

Color workerJobStatusColor(BuildContext context, WorkerJobStatus status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    WorkerJobStatus.accepted => colors.primary,
    WorkerJobStatus.onTheWay => const Color(0xFF0284C7),
    WorkerJobStatus.inProgress => SkillNovaColors.warning,
    WorkerJobStatus.completed => SkillNovaColors.success,
    WorkerJobStatus.cancelled => colors.error,
    WorkerJobStatus.unknown => colors.onSurfaceVariant,
  };
}

IconData workerJobStatusIcon(WorkerJobStatus status) => switch (status) {
  WorkerJobStatus.accepted => Icons.task_alt_rounded,
  WorkerJobStatus.onTheWay => Icons.navigation_rounded,
  WorkerJobStatus.inProgress => Icons.handyman_rounded,
  WorkerJobStatus.completed => Icons.verified_rounded,
  WorkerJobStatus.cancelled => Icons.cancel_outlined,
  WorkerJobStatus.unknown => Icons.help_outline_rounded,
};

class WorkerJobStatusBadge extends StatelessWidget {
  const WorkerJobStatusBadge({super.key, required this.status});

  final WorkerJobStatusPresentation status;

  @override
  Widget build(BuildContext context) {
    final color = workerJobStatusColor(context, status.status);
    return Semantics(
      label: 'Job status: ${status.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(workerJobStatusIcon(status.status), color: color, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                status.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkerJobCustomerAvatar extends StatelessWidget {
  const WorkerJobCustomerAvatar({
    super.key,
    required this.customer,
    this.size = 48,
  });

  final WorkerJobCustomer? customer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = customer;
    final initials = value?.initials ?? 'C';
    final fallback = Container(
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
      child: SizedBox(
        width: size,
        height: size,
        child: value?.photoUrl.isNotEmpty == true
            ? Image.network(
                value!.photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class WorkerJobCard extends StatelessWidget {
  const WorkerJobCard({super.key, required this.job, required this.onView});

  final WorkerJob job;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = job.imageUrls.firstOrNull;
    return Container(
      key: ValueKey('worker-job-${job.id}'),
      margin: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        child: Padding(
          padding: const EdgeInsets.all(SkillNovaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        SkillNovaRadius.medium,
                      ),
                      child: Image.network(
                        image,
                        width: 66,
                        height: 66,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imageFallback(context),
                      ),
                    ),
                    const SizedBox(width: SkillNovaSpacing.sm),
                  ] else ...[
                    _imageFallback(context),
                    const SizedBox(width: SkillNovaSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WorkerJobStatusBadge(status: job.status),
                        const SizedBox(height: SkillNovaSpacing.xs),
                        Text(
                          job.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          job.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SkillNovaSpacing.sm),
              Row(
                children: [
                  WorkerJobCustomerAvatar(customer: job.customer, size: 38),
                  const SizedBox(width: SkillNovaSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.customer?.name ??
                              'Customer information unavailable',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          job.serviceArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SkillNovaSpacing.sm),
              Wrap(
                spacing: SkillNovaSpacing.sm,
                runSpacing: SkillNovaSpacing.xs,
                children: [
                  _fact(
                    context,
                    Icons.payments_outlined,
                    'Posted budget: ${formatWorkerJobBudget(job.budget)}',
                  ),
                  _fact(
                    context,
                    Icons.calendar_today_outlined,
                    workerJobDateLabel(job.relevantDate),
                  ),
                  if (job.distanceKm != null)
                    _fact(
                      context,
                      Icons.near_me_outlined,
                      '${job.distanceKm!.toStringAsFixed(1)} km away',
                    ),
                ],
              ),
              if (job.status.status == WorkerJobStatus.cancelled &&
                  job.cancellationReason.isNotEmpty) ...[
                const SizedBox(height: SkillNovaSpacing.sm),
                Text(
                  'Reason: ${job.cancellationReason}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (job.status.status == WorkerJobStatus.completed) ...[
                const SizedBox(height: SkillNovaSpacing.sm),
                Row(
                  children: [
                    Icon(
                      job.review == null
                          ? Icons.star_outline_rounded
                          : Icons.star_rounded,
                      size: 18,
                      color: SkillNovaColors.rating,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      job.review == null
                          ? 'No review yet'
                          : '${job.review!.rating.toStringAsFixed(1)} customer review',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: SkillNovaSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onView,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('View job'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback(BuildContext context) => Container(
    width: 66,
    height: 66,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
    ),
    child: Icon(
      Icons.home_repair_service_outlined,
      color: Theme.of(context).colorScheme.primary,
    ),
  );

  Widget _fact(BuildContext context, IconData icon, String label) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 64,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerJobsStateView extends StatelessWidget {
  const WorkerJobsStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SkillNovaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(SkillNovaRadius.large),
              ),
              child: Icon(
                icon,
                size: 34,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: SkillNovaSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: SkillNovaSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SkillNovaSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class WorkerJobSection extends StatelessWidget {
  const WorkerJobSection({
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: SkillNovaSpacing.xs),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          child,
        ],
      ),
    );
  }
}
