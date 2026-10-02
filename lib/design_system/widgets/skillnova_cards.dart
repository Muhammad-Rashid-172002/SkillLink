import 'package:flutter/material.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Centred so the 44px-tall action lines up with the title text rather
    // than floating above its baseline.
    return Row(
      crossAxisAlignment: subtitle == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: SkillNovaSpacing.xxs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                const SizedBox(width: SkillNovaSpacing.xxs),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
      ],
    );
  }
}

class ServiceCategoryCard extends StatelessWidget {
  const ServiceCategoryCard({
    super.key,
    required this.label,
    required this.icon,
    this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;

  /// Ignored by default: categories share one brand tint so the grid reads
  /// as one calm system instead of a rainbow. Pass to override deliberately.
  final Color? accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Book $label service',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          child: Container(
            constraints: const BoxConstraints(minWidth: 112),
            padding: const EdgeInsets.all(SkillNovaSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        accent?.withValues(alpha: 0.10) ??
                        colors.primaryContainer,
                    borderRadius: BorderRadius.circular(SkillNovaRadius.small),
                  ),
                  child: Icon(icon, color: accent ?? colors.primary, size: 23),
                ),
                const Spacer(),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({
    super.key,
    required this.name,
    required this.skill,
    required this.rating,
    required this.reviewCount,
    required this.verified,
    required this.onViewProfile,
    required this.onBook,
    this.photoUrl,
    this.completedJobs,
    this.startingRate,
    this.available,
    this.experience,
    this.distanceKm,
    this.width = 286,
  });

  final String name;
  final String skill;
  final double rating;
  final int reviewCount;
  final bool verified;
  final String? photoUrl;
  final int? completedJobs;
  final String? startingRate;
  final bool? available;
  final String? experience;
  final double? distanceKm;
  final double? width;
  final VoidCallback onViewProfile;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    return Container(
      width: width,
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: hasPhoto
                      ? Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _InitialAvatar(name: name),
                        )
                      : _InitialAvatar(name: name),
                ),
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
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: SkillNovaSpacing.xxs),
                          Tooltip(
                            message: 'Identity verified',
                            child: Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: SkillNovaSpacing.xxs),
                    Text(
                      skill,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: SkillNovaSpacing.xs),
                    // A rating with zero reviews is meaningless; call new
                    // professionals out honestly instead.
                    if (reviewCount == 0)
                      Text(
                        'New on SkillNova',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                        ),
                      )
                    else
                      Semantics(
                        label:
                            'Rated ${rating.toStringAsFixed(1)} from '
                            '$reviewCount review${reviewCount == 1 ? '' : 's'}',
                        excludeSemantics: true,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: SkillNovaColors.rating,
                              size: 18,
                            ),
                            const SizedBox(width: SkillNovaSpacing.xxs),
                            Text(
                              '${rating.toStringAsFixed(1)} ($reviewCount)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          Wrap(
            spacing: SkillNovaSpacing.xs,
            runSpacing: SkillNovaSpacing.xs,
            children: [
              if (verified)
                const _InfoChip(icon: Icons.shield_outlined, label: 'Verified'),
              if (completedJobs != null && completedJobs! > 0)
                _InfoChip(
                  icon: Icons.check_circle_outline_rounded,
                  label: '$completedJobs job${completedJobs == 1 ? '' : 's'}',
                ),
              if (available == true)
                const _InfoChip(
                  icon: Icons.schedule_rounded,
                  label: 'Available',
                  success: true,
                ),
              if (experience != null && experience!.isNotEmpty)
                _InfoChip(
                  icon: Icons.workspace_premium_outlined,
                  label: experience!,
                ),
              if (distanceKm != null)
                _InfoChip(
                  icon: Icons.near_me_outlined,
                  label: _distanceLabel(distanceKm!),
                ),
            ],
          ),
          if (startingRate != null && startingRate!.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            Text(
              'Starting from $startingRate',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ],
          const SizedBox(height: SkillNovaSpacing.md),
          Row(
            children: [
              Expanded(
                // Short label: two equal buttons in a ~280px card leave no
                // room for "View profile" without truncating.
                child: Semantics(
                  button: true,
                  label: 'View profile',
                  onTap: onViewProfile,
                  excludeSemantics: true,
                  child: SecondaryButton(
                    label: 'Profile',
                    onPressed: onViewProfile,
                  ),
                ),
              ),
              const SizedBox(width: SkillNovaSpacing.xs),
              Expanded(
                child: PrimaryButton(label: 'Book', onPressed: onBook),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _distanceLabel(double distance) {
    if (distance < 1) return '${(distance * 1000).round()} m away';
    return '${distance.toStringAsFixed(distance < 10 ? 1 : 0)} km away';
  }
}

class ActiveBookingCard extends StatelessWidget {
  const ActiveBookingCard({
    super.key,
    required this.service,
    required this.statusLabel,
    required this.statusMessage,
    required this.progress,
    required this.onTrack,
    this.workerLabel,
  });

  final String service;
  final String statusLabel;
  final String statusMessage;
  final double progress;
  final String? workerLabel;
  final VoidCallback onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(SkillNovaSpacing.lg),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: colors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(SkillNovaRadius.small),
                ),
                child: Icon(
                  Icons.home_repair_service_rounded,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (workerLabel != null) ...[
                      const SizedBox(height: SkillNovaSpacing.xxs),
                      Text(workerLabel!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          // The status sits on its own line so the job title keeps the full
          // width on narrow phones instead of truncating beside a pill.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SkillNovaSpacing.sm,
              vertical: SkillNovaSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
            ),
            child: Text(
              statusLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text(statusMessage, style: theme.textTheme.bodyMedium),
          const SizedBox(height: SkillNovaSpacing.sm),
          Semantics(
            label: 'Booking progress ${(progress * 100).round()} percent',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 6,
                backgroundColor: colors.surface,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: SkillNovaSpacing.md),
          PrimaryButton(
            label: 'Track booking',
            icon: Icons.arrow_forward_rounded,
            onPressed: onTrack,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

/// Purposeful empty / error state: what is empty, why, and what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = SkillNovaTone.info,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final SkillNovaTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: SkillNovaSpacing.xl,
          vertical: SkillNovaSpacing.xxl,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        ),
        child: Column(
          // Hug the content; inside a Center this must not fill the screen.
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: icon, tone: tone, size: 56),
            const SizedBox(height: SkillNovaSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: SkillNovaSpacing.xxs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: SkillNovaSpacing.lg),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends EmptyState {
  const ErrorState({
    super.key,
    required super.title,
    required super.message,
    super.actionLabel,
    super.onAction,
  }) : super(icon: Icons.cloud_off_outlined, tone: SkillNovaTone.neutral);
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.width, this.height = 148});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(SkillNovaRadius.large),
          border: Border.all(color: colors.outlineVariant),
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          initials.isEmpty ? 'SN' : initials,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colors.primary),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.success = false,
  });

  final IconData icon;
  final String label;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success
        ? SkillNovaColors.success
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SkillNovaSpacing.xs,
        vertical: SkillNovaSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: SkillNovaSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
