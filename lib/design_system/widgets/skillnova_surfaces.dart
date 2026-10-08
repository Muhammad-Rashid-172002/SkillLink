import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';

/// Foreground/background pair for a semantic tone, correct in light and dark.
@immutable
class SkillNovaToneColors {
  const SkillNovaToneColors(this.foreground, this.background);

  final Color foreground;
  final Color background;

  static SkillNovaToneColors of(BuildContext context, SkillNovaTone tone) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    Color soft(Color base) => base.withValues(alpha: dark ? 0.18 : 0.10);
    return switch (tone) {
      SkillNovaTone.success => SkillNovaToneColors(
        dark ? const Color(0xFF47CD89) : SkillNovaColors.success,
        soft(SkillNovaColors.success),
      ),
      SkillNovaTone.warning => SkillNovaToneColors(
        dark ? const Color(0xFFFDB022) : SkillNovaColors.warning,
        soft(SkillNovaColors.warning),
      ),
      SkillNovaTone.error => SkillNovaToneColors(
        dark ? const Color(0xFFF97066) : SkillNovaColors.error,
        soft(SkillNovaColors.error),
      ),
      SkillNovaTone.info => SkillNovaToneColors(
        colors.primary,
        colors.primaryContainer,
      ),
      SkillNovaTone.neutral => SkillNovaToneColors(
        colors.onSurfaceVariant,
        colors.surfaceContainer,
      ),
    };
  }
}

/// Small status pill. Always pairs color with text (and optionally an icon)
/// so meaning never relies on color alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = SkillNovaTone.neutral,
    this.icon,
  });

  final String label;
  final SkillNovaTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tc = SkillNovaToneColors.of(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tc.background,
        borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tc.foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tc.foreground,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinted rounded-square icon used at the start of rows and cards.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.tone = SkillNovaTone.info,
    this.size = 40,
  });

  final IconData icon;
  final SkillNovaTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tc = SkillNovaToneColors.of(context, tone);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tc.background,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, size: size * 0.5, color: tc.foreground),
      ),
    );
  }
}

/// The standard content surface: white (or dark surface) with a hairline
/// border, no heavy shadow. Becomes pressable when [onTap] is given.
class SkillNovaCard extends StatelessWidget {
  const SkillNovaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(SkillNovaSpacing.md),
    this.color,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(SkillNovaRadius.large);
    final card = Material(
      color: color ?? colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
    final wrapped = onTap == null ? card : PressableScale(child: card);
    if (semanticLabel == null) return wrapped;
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: wrapped,
    );
  }
}

/// Contextual message block: what happened, why, and an optional next step.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = SkillNovaTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final SkillNovaTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tc = SkillNovaToneColors.of(context, tone);
    final text = Theme.of(context).textTheme;
    final defaultIcon = switch (tone) {
      SkillNovaTone.success => Icons.check_circle_outline_rounded,
      SkillNovaTone.warning => Icons.error_outline_rounded,
      SkillNovaTone.error => Icons.report_gmailerrorred_rounded,
      _ => Icons.info_outline_rounded,
    };
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(SkillNovaSpacing.md),
        decoration: BoxDecoration(
          color: tc.background,
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, size: 22, color: tc.foreground),
            const SizedBox(width: SkillNovaSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  if (message != null) ...[
                    const SizedBox(height: 2),
                    Text(message!, style: text.bodyMedium),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: SkillNovaSpacing.xs),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: tc.foreground,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title + optional subtitle + trailing action at the top of a tab or page.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: text.headlineSmall),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: text.bodyMedium),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Grouped list (settings, menus, details). Rows are separated by inset
/// hairlines inside one card instead of each row being its own card.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(
          Divider(
            height: 1,
            indent: 68,
            endIndent: SkillNovaSpacing.md,
            color: colors.outlineVariant,
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, SkillNovaSpacing.xs),
            child: Semantics(
              header: true,
              child: Text(
                title!.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        SkillNovaCard(
          padding: EdgeInsets.zero,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// One row inside a [ListGroup].
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.tone = SkillNovaTone.neutral,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final SkillNovaTone tone;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final effectiveTone = destructive ? SkillNovaTone.error : tone;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SkillNovaSpacing.md,
            vertical: SkillNovaSpacing.sm,
          ),
          child: Row(
            children: [
              IconTile(icon: icon, tone: effectiveTone, size: 36),
              const SizedBox(width: SkillNovaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        color: destructive ? colors.error : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact metric. Only render with real values.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = SkillNovaTone.info,
  });

  final String label;
  final String value;
  final IconData? icon;
  final SkillNovaTone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: SkillNovaCard(
        padding: const EdgeInsets.all(SkillNovaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              IconTile(icon: icon!, tone: tone, size: 32),
              const SizedBox(height: SkillNovaSpacing.sm),
            ],
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Constrains page content to a readable width on tablets/desktop and keeps
/// the standard gutter on phones.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // heightFactor 1: size to the child, so this also works inside bottom
    // bars instead of expanding to fill the screen.
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// App bar for a primary tab (Bookings, Profile, ...): a large title that
/// matches tabs with in-content headers, and a back arrow only when the page
/// was pushed rather than shown as a tab.
PreferredSizeWidget tabRootAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    toolbarHeight: 64,
    automaticallyImplyLeading: automaticallyImplyLeading,
    title: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    ),
    actions: actions,
    bottom: bottom,
  );
}
