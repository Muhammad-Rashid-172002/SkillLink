import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';

/// "Email → Phone → Profile" progress used through account setup.
class VerificationProgress extends StatelessWidget {
  const VerificationProgress({super.key, required this.step});

  /// 1-based current step.
  final int step;

  static const _labels = ['Email', 'Phone', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label: 'Account setup, step $step of ${_labels.length}: '
          '${_labels[step - 1]}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: SkillNovaMotion.medium,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < step ? colors.primary : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _labels[i],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: i < step
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (i < _labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class VerificationHeroIcon extends StatelessWidget {
  const VerificationHeroIcon({
    super.key,
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SkillNovaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: SkillNovaSpacing.sm),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
