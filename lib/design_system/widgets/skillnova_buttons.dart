import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';

/// Button hierarchy:
/// * [primary] – the one main action on a screen.
/// * [secondary] – tonal, for supporting actions.
/// * [outline] – neutral bordered action.
/// * [ghost] – low-emphasis text action.
/// * [destructive] – irreversible / dangerous action.
enum SkillNovaButtonVariant { primary, secondary, outline, ghost, destructive }

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
      SkillNovaButtonVariant.primary =>
        Theme.of(context).colorScheme.onPrimary,
      SkillNovaButtonVariant.destructive => Colors.white,
      SkillNovaButtonVariant.outline => Theme.of(context).colorScheme.onSurface,
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
      SkillNovaButtonVariant.secondary => FilledButton.tonal(
        onPressed: action,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        child: content,
      ),
      SkillNovaButtonVariant.outline => OutlinedButton(
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

    return Semantics(
      button: true,
      enabled: action != null,
      label: loading ? '$label, loading' : null,
      excludeSemantics: loading,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        child: button,
      ),
    );
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

class OutlineButton extends SkillNovaButton {
  const OutlineButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.loading,
    super.fullWidth,
  }) : super(variant: SkillNovaButtonVariant.outline);
}

class DestructiveButton extends SkillNovaButton {
  const DestructiveButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.loading,
    super.fullWidth,
  }) : super(variant: SkillNovaButtonVariant.destructive);
}
