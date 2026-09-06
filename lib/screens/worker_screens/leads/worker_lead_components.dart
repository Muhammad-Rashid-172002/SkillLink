import 'package:flutter/material.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_models.dart';

class WorkerLeadCard extends StatelessWidget {
  const WorkerLeadCard({
    super.key,
    required this.lead,
    required this.onView,
    this.compact = false,
  });

  final WorkerLead lead;
  final VoidCallback onView;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = lead.imageUrls.firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        key: ValueKey('lead-card-${lead.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LeadThumbnail(category: lead.category, imageUrl: image),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lead.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: colors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            WorkerLeadUrgencyBadge(urgency: lead.urgency),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          lead.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 11),
                Text(
                  lead.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 13),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _LeadFact(
                    icon: Icons.location_on_outlined,
                    text: lead.publicServiceArea,
                  ),
                  if (lead.distanceKm != null)
                    _LeadFact(
                      icon: Icons.near_me_outlined,
                      text: workerLeadDistance(lead.distanceKm),
                    ),
                  _LeadFact(
                    icon: Icons.schedule_rounded,
                    text: workerLeadRelativeTime(lead.createdAt),
                  ),
                  if (lead.customer != null)
                    _LeadFact(
                      icon: Icons.person_outline_rounded,
                      text: lead.customer!.publicName,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: colors.outlineVariant, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Posted budget',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lead.postedBudget,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    key: ValueKey('view-lead-${lead.id}'),
                    onPressed: onView,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('View lead'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkerLeadReadinessBanner extends StatelessWidget {
  const WorkerLeadReadinessBanner({
    super.key,
    required this.readiness,
    this.onCredits,
  });

  final WorkerReadiness readiness;
  final VoidCallback? onCredits;

  @override
  Widget build(BuildContext context) {
    if (readiness.state == WorkerReadinessState.ready) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final needsCredits = readiness.state == WorkerReadinessState.needsCredits;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: needsCredits ? colors.tertiaryContainer : colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            needsCredits ? Icons.toll_outlined : Icons.lock_outline_rounded,
            color: needsCredits
                ? colors.onTertiaryContainer
                : colors.onErrorContainer,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  readiness.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(readiness.message),
                if (needsCredits && onCredits != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onCredits,
                    child: const Text('Get credits'),
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

class WorkerLeadUrgencyBadge extends StatelessWidget {
  const WorkerLeadUrgencyBadge({super.key, required this.urgency});
  final String urgency;

  @override
  Widget build(BuildContext context) {
    final normalized = urgency.toLowerCase();
    final colors = Theme.of(context).colorScheme;
    final (color, icon) = switch (normalized) {
      'emergency' => (colors.error, Icons.warning_amber_rounded),
      'urgent' => (const Color(0xFFD97706), Icons.bolt_rounded),
      _ => (colors.primary, Icons.schedule_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            urgency,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerLeadEmptyState extends StatelessWidget {
  const WorkerLeadEmptyState({
    super.key,
    required this.filtered,
    required this.skill,
    this.onClear,
  });

  final bool filtered;
  final String skill;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 20),
    child: Column(
      children: [
        Icon(
          filtered ? Icons.manage_search_rounded : Icons.inbox_outlined,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          filtered ? 'No leads match your filters' : 'No matching leads yet',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          filtered
              ? 'Try clearing search or filters.'
              : 'New $skill requests will appear here when customers post them.',
          textAlign: TextAlign.center,
        ),
        if (filtered && onClear != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ],
    ),
  );
}

class WorkerLeadErrorState extends StatelessWidget {
  const WorkerLeadErrorState({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load leads',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class WorkerLeadCustomerAvatar extends StatelessWidget {
  const WorkerLeadCustomerAvatar({
    super.key,
    required this.customer,
    this.radius = 26,
  });

  final WorkerLeadCustomer? customer;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = customer?.photoUrl ?? '';
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      foregroundColor: colors.onPrimaryContainer,
      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
      onBackgroundImageError: photo.isNotEmpty ? (_, _) {} : null,
      child: photo.isEmpty
          ? Text(
              customer?.initials ?? 'C',
              style: const TextStyle(fontWeight: FontWeight.w800),
            )
          : null,
    );
  }
}

class _LeadThumbnail extends StatelessWidget {
  const _LeadThumbnail({required this.category, this.imageUrl});
  final String category;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _categoryIcon(colors),
            )
          : _categoryIcon(colors),
    );
  }

  Widget _categoryIcon(ColorScheme colors) =>
      Icon(workerLeadCategoryIcon(category), color: colors.onPrimaryContainer);
}

class _LeadFact extends StatelessWidget {
  const _LeadFact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 15,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 4),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}

IconData workerLeadCategoryIcon(String category) {
  final value = normalizeWorkerCategory(category);
  if (value.contains('electric')) return Icons.electrical_services_rounded;
  if (value.contains('plumb')) return Icons.plumbing_rounded;
  if (value.contains('ac')) return Icons.ac_unit_rounded;
  if (value.contains('clean')) return Icons.cleaning_services_rounded;
  if (value.contains('paint')) return Icons.format_paint_rounded;
  if (value.contains('carp')) return Icons.carpenter_rounded;
  if (value.contains('mechanic')) return Icons.car_repair_rounded;
  return Icons.handyman_rounded;
}
