import 'package:flutter/material.dart';
import 'package:skill_link/core/format/money.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';

import 'worker_profile_models.dart';

class WorkerProfileAvatar extends StatelessWidget {
  const WorkerProfileAvatar({
    super.key,
    required this.profile,
    this.radius = 45,
  });

  final WorkerProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Text(
        profile.initials,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primary.withValues(alpha: .10),
      child: ClipOval(
        child: profile.photoUrl.isEmpty
            ? fallback
            : Image.network(
                profile.photoUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class WorkerProfileHeader extends StatelessWidget {
  const WorkerProfileHeader({
    super.key,
    required this.profile,
    required this.onEdit,
    required this.onSettings,
  });

  final WorkerProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SkillNovaSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              key: const ValueKey('worker-profile-settings'),
              tooltip: 'Settings',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          WorkerProfileAvatar(profile: profile),
          const SizedBox(height: SkillNovaSpacing.md),
          Text(
            profile.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: SkillNovaSpacing.xxs),
          Text(
            profile.skill,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.primary),
          ),
          if (profile.serviceArea.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: colors.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    profile.serviceArea,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: SkillNovaSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: profile.rawVerificationStatus == 'approved'
                    ? Icons.verified_rounded
                    : Icons.shield_outlined,
                label: profile.verificationLabel,
                positive: profile.rawVerificationStatus == 'approved',
              ),
              _StatusPill(
                icon: _readinessIcon(profile.readiness.state),
                label: profile.readiness.title,
                positive: profile.readiness.state == WorkerReadinessState.ready,
              ),
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('worker-profile-edit'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkerReadinessCard extends StatelessWidget {
  const WorkerReadinessCard({super.key, required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final readiness = profile.readiness;
    final colors = Theme.of(context).colorScheme;
    final positive = readiness.state == WorkerReadinessState.ready;
    return Semantics(
      label: 'Readiness status: ${readiness.title}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SkillNovaSpacing.md),
        decoration: BoxDecoration(
          color: positive
              ? SkillNovaColors.success.withValues(alpha: .08)
              : colors.secondaryContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          border: Border.all(
            color: positive
                ? SkillNovaColors.success.withValues(alpha: .35)
                : colors.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _readinessIcon(readiness.state),
              color: positive
                  ? SkillNovaColors.success
                  : colors.onSecondaryContainer,
            ),
            const SizedBox(width: SkillNovaSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    readiness.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(readiness.message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkerAvailabilityCard extends StatelessWidget {
  const WorkerAvailabilityCard({
    super.key,
    required this.profile,
    required this.updating,
    required this.onChanged,
  });

  final WorkerProfile profile;
  final bool updating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final blocker = profile.availabilityBlocker;
    final enabled = blocker == null && !updating;
    final effectiveValue = blocker == null && profile.canAcceptJobs;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
      ),
      child: SwitchListTile(
        key: const ValueKey('worker-accepting-jobs-toggle'),
        value: effectiveValue,
        onChanged: enabled ? onChanged : null,
        secondary: updating
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.work_outline_rounded),
        title: const Text('Accepting new jobs'),
        subtitle: Text(
          blocker?.message ??
              (effectiveValue
                  ? 'Your eligible profile can appear to customers and receive matching leads.'
                  : 'Your profile is eligible, but new job discovery is switched off.'),
        ),
      ),
    );
  }
}

class WorkerProfileSummary extends StatelessWidget {
  const WorkerProfileSummary({super.key, required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            icon: Icons.star_rounded,
            value: profile.rating > 0 ? profile.rating.toStringAsFixed(1) : '—',
            label: '${profile.reviewCount} reviews',
          ),
        ),
        const SizedBox(width: SkillNovaSpacing.xs),
        Expanded(
          child: _SummaryItem(
            icon: Icons.toll_outlined,
            value: '${profile.credits}',
            label: 'Lead credits',
          ),
        ),
      ],
    );
  }
}

class WorkerProfessionalSnapshot extends StatelessWidget {
  const WorkerProfessionalSnapshot({super.key, required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DetailRow(
          icon: Icons.handyman_outlined,
          label: 'Primary service',
          value: profile.skill,
        ),
        const Divider(height: 1),
        _DetailRow(
          icon: Icons.location_on_outlined,
          label: 'Service area',
          value: profile.serviceArea.isEmpty
              ? 'Not added'
              : profile.serviceArea,
        ),
        const Divider(height: 1),
        _DetailRow(
          icon: Icons.payments_outlined,
          label: 'Starting service rate',
          value: profile.hourlyRate.isEmpty
              ? 'Not added'
              : formatHourlyRate(profile.hourlyRate),
        ),
        const Divider(height: 1),
        _DetailRow(
          icon: Icons.work_history_outlined,
          label: 'Experience',
          value: profile.experience.isEmpty
              ? 'Not added'
              : workerExperienceLabel(profile.experience),
        ),
        if (profile.bio.isNotEmpty) ...[
          const Divider(height: 1),
          _DetailRow(
            icon: Icons.notes_outlined,
            label: 'Professional bio',
            value: profile.bio,
            maxLines: 6,
            longText: true,
          ),
        ],
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 3,
    this.longText = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  /// Prose (like a bio) reads better in body text than in a bold title.
  final bool longText;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 68,
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(
        value,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: longText
            ? Theme.of(context).textTheme.bodyLarge
            : Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.positive,
  });

  final IconData icon;
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = positive ? SkillNovaColors.success : colors.secondary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _readinessIcon(WorkerReadinessState state) => switch (state) {
  WorkerReadinessState.ready => Icons.check_circle_outline_rounded,
  WorkerReadinessState.needsCredits => Icons.toll_outlined,
  WorkerReadinessState.blocked ||
  WorkerReadinessState.inactive => Icons.block_outlined,
  WorkerReadinessState.verificationPending ||
  WorkerReadinessState.verificationRejected ||
  WorkerReadinessState.verificationRequired => Icons.shield_outlined,
  _ => Icons.info_outline_rounded,
};

/// "6" → "6 years"; keeps values that already carry a unit ("6 years",
/// "6+ yrs") untouched.
String workerExperienceLabel(String raw) {
  final value = raw.trim();
  final years = int.tryParse(value);
  if (years == null) return value;
  return years == 1 ? '1 year' : '$years years';
}
