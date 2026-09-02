import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/worker_screens/profile_screen/worker_public_profile_repository.dart';

class WorkerProfileHero extends StatelessWidget {
  const WorkerProfileHero({
    super.key,
    required this.name,
    required this.skill,
    required this.photoUrl,
    required this.rating,
    required this.reviewCount,
    required this.verified,
    this.location,
    this.distanceKm,
  });

  final String name;
  final String skill;
  final String photoUrl;
  final double rating;
  final int reviewCount;
  final bool verified;
  final String? location;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SkillNovaSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: Column(
        children: [
          _PublicAvatar(name: name, photoUrl: photoUrl, size: 112),
          const SizedBox(height: SkillNovaSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              if (verified) ...[
                const SizedBox(width: SkillNovaSpacing.xs),
                Tooltip(
                  message: 'Identity verified',
                  child: Icon(
                    Icons.verified_rounded,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: SkillNovaSpacing.xxs),
          Text(skill, style: theme.textTheme.bodyLarge),
          if ((location != null && location!.isNotEmpty) ||
              distanceKm != null) ...[
            const SizedBox(height: SkillNovaSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  location != null && location!.isNotEmpty
                      ? Icons.location_on_outlined
                      : Icons.near_me_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: SkillNovaSpacing.xxs),
                if (location != null && location!.isNotEmpty)
                  Flexible(
                    child: Text(
                      location!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                if (distanceKm != null &&
                    location != null &&
                    location!.isNotEmpty) ...[
                  Text(' • ', style: theme.textTheme.bodyMedium),
                ],
                if (distanceKm != null) ...[
                  Text(
                    _distance(distanceKm!),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: SkillNovaSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SkillNovaSpacing.md,
              vertical: SkillNovaSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: SkillNovaSpacing.xxs,
              children: [
                Icon(
                  reviewCount > 0 && rating > 0
                      ? Icons.star_rounded
                      : Icons.auto_awesome_outlined,
                  color: reviewCount > 0 && rating > 0
                      ? SkillNovaColors.rating
                      : colors.primary,
                  size: 20,
                ),
                Text(
                  reviewCount > 0 && rating > 0
                      ? '${rating.toStringAsFixed(1)} ($reviewCount ${reviewCount == 1 ? 'review' : 'reviews'})'
                      : 'New professional',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _distance(double value) {
    if (value < 1) return '${(value * 1000).round()} m away';
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)} km away';
  }
}

class WorkerVerificationCard extends StatelessWidget {
  const WorkerVerificationCard({
    super.key,
    required this.identityVerified,
    required this.emailVerified,
    required this.phoneVerified,
  });

  final bool identityVerified;
  final bool emailVerified;
  final bool phoneVerified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <({IconData icon, String label})>[
      if (identityVerified)
        (icon: Icons.badge_outlined, label: 'Identity verified'),
      if (emailVerified)
        (icon: Icons.mark_email_read_outlined, label: 'Email verified'),
      if (phoneVerified)
        (icon: Icons.phone_iphone_outlined, label: 'Phone verified'),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return _ProfileSection(
      title: 'Trust & verification',
      child: Wrap(
        spacing: SkillNovaSpacing.xs,
        runSpacing: SkillNovaSpacing.xs,
        children: items.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SkillNovaSpacing.sm,
              vertical: SkillNovaSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: SkillNovaColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: SkillNovaSpacing.xxs,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: SkillNovaColors.success,
                ),
                Text(
                  item.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: SkillNovaColors.success,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class WorkerAboutCard extends StatelessWidget {
  const WorkerAboutCard({
    super.key,
    required this.skill,
    this.bio,
    this.experience,
    this.rate,
  });

  final String skill;
  final String? bio;
  final String? experience;
  final String? rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (bio != null && bio!.isNotEmpty)
          _ProfileSection(
            title: 'About',
            child: Text(bio!, style: theme.textTheme.bodyMedium),
          ),
        if (bio != null && bio!.isNotEmpty)
          const SizedBox(height: SkillNovaSpacing.md),
        _ProfileSection(
          title: 'Service details',
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.handyman_outlined,
                label: 'Primary service',
                value: skill,
              ),
              if (experience != null && experience!.isNotEmpty) ...[
                const Divider(height: SkillNovaSpacing.xl),
                _DetailRow(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Experience',
                  value: experience!,
                ),
              ],
              if (rate != null && rate!.isNotEmpty) ...[
                const Divider(height: SkillNovaSpacing.xl),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Starting rate',
                  value: rate!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class WorkerRatingSummary extends StatelessWidget {
  const WorkerRatingSummary({
    super.key,
    required this.rating,
    required this.reviewCount,
  });

  final double rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(rating.toStringAsFixed(1), style: theme.textTheme.displaySmall),
        const SizedBox(width: SkillNovaSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stars(rating: rating),
              const SizedBox(height: SkillNovaSpacing.xxs),
              Text(
                '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WorkerReviewCard extends StatelessWidget {
  const WorkerReviewCard({super.key, required this.review});

  final PublicWorkerReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PublicAvatar(
                name: review.customerName,
                photoUrl: review.customerPhotoUrl,
                size: 44,
              ),
              const SizedBox(width: SkillNovaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: SkillNovaSpacing.xxs),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: SkillNovaSpacing.xxs,
                      children: [
                        _Stars(rating: review.rating, size: 15),
                        if (review.createdAt != null) ...[
                          Text(
                            '• ${_dateLabel(review.createdAt!)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            Text(review.comment, style: theme.textTheme.bodyMedium),
          ],
          if (review.service.isNotEmpty || review.verifiedBooking) ...[
            const SizedBox(height: SkillNovaSpacing.sm),
            Wrap(
              spacing: SkillNovaSpacing.xs,
              runSpacing: SkillNovaSpacing.xs,
              children: [
                if (review.service.isNotEmpty)
                  _ReviewBadge(
                    icon: Icons.home_repair_service_outlined,
                    label: review.service,
                  ),
                if (review.verifiedBooking)
                  const _ReviewBadge(
                    icon: Icons.verified_outlined,
                    label: 'Verified booking',
                    success: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.child});

  final String title;
  final Widget child;

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SkillNovaSpacing.md),
          child,
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: theme.colorScheme.primary),
        const SizedBox(width: SkillNovaSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: SkillNovaSpacing.xxs),
              Text(value, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  final String name;
  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    Widget fallback() => ColoredBox(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          initials.isEmpty ? 'SN' : initials,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: colors.primary),
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineVariant, width: 2),
      ),
      child: photoUrl.isEmpty
          ? KeyedSubtree(
              key: ValueKey('avatar-fallback-$name'),
              child: fallback(),
            )
          : Image.network(
              key: ValueKey('avatar-image-$name'),
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 17});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.round()
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          color: SkillNovaColors.rating,
          size: size,
        );
      }),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge({
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
        vertical: 6,
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
