import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';

enum SkillNovaButtonVariant { primary, secondary, ghost, destructive }

class SkillNovaButton extends StatelessWidget {
  const SkillNovaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
    this.variant = SkillNovaButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final SkillNovaButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final action = loading ? null : onPressed;
    final loadingColor = switch (variant) {
      SkillNovaButtonVariant.primary ||
      SkillNovaButtonVariant.destructive => Colors.white,
      _ => Theme.of(context).colorScheme.primary,
    };
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: loadingColor,
              ),
            )
          : Row(
              key: const ValueKey('content'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 19),
                  const SizedBox(width: SkillNovaSpacing.xs),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    final button = switch (variant) {
      SkillNovaButtonVariant.primary => ElevatedButton(
        onPressed: action,
        child: content,
      ),
      SkillNovaButtonVariant.secondary => OutlinedButton(
        onPressed: action,
        child: content,
      ),
      SkillNovaButtonVariant.ghost => TextButton(
        onPressed: action,
        child: content,
      ),
      SkillNovaButtonVariant.destructive => ElevatedButton(
        onPressed: action,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        child: content,
      ),
    };

    return SizedBox(width: fullWidth ? double.infinity : null, child: button);
  }
}

class PrimaryButton extends SkillNovaButton {
  const PrimaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.loading,
    super.fullWidth,
  }) : super(variant: SkillNovaButtonVariant.primary);
}

class SecondaryButton extends SkillNovaButton {
  const SecondaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.loading,
    super.fullWidth,
  }) : super(variant: SkillNovaButtonVariant.secondary);
}

class GhostButton extends SkillNovaButton {
  const GhostButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.loading,
    super.fullWidth,
  }) : super(variant: SkillNovaButtonVariant.ghost);
}
