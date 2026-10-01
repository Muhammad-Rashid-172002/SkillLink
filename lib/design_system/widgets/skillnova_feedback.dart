import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';

enum SkillNovaTone { neutral, success, warning, error, info }

/// Consistent, accessible snackbar used for every transient message.
abstract final class SkillNovaToast {
  static void show(
    BuildContext context,
    String message, {
    SkillNovaTone tone = SkillNovaTone.neutral,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final icon = switch (tone) {
      SkillNovaTone.success => Icons.check_circle_rounded,
      SkillNovaTone.warning => Icons.warning_amber_rounded,
      SkillNovaTone.error => Icons.error_rounded,
      SkillNovaTone.info => Icons.info_rounded,
      SkillNovaTone.neutral => null,
    };
    final iconColor = switch (tone) {
      SkillNovaTone.success => const Color(0xFF47CD89),
      SkillNovaTone.warning => const Color(0xFFFDB022),
      SkillNovaTone.error => const Color(0xFFF97066),
      SkillNovaTone.info => const Color(0xFF84ADFF),
      SkillNovaTone.neutral => null,
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: SkillNovaSpacing.sm),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          action: actionLabel == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
        ),
      );
  }
}

/// Full-area state view for empty, error and offline situations.
///
/// Every state explains what happened and offers a relevant next step.
class SkillNovaStatusView extends StatelessWidget {
  const SkillNovaStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.tone = SkillNovaTone.neutral,
    this.compact = false,
  });

  const SkillNovaStatusView.offline({
    super.key,
    this.onAction,
    this.compact = false,
  }) : icon = Icons.wifi_off_rounded,
       title = 'You’re offline',
       message =
           'Check your Wi-Fi or mobile data, then try again. '
           'Anything you already loaded is still available.',
       actionLabel = 'Try again',
       secondaryLabel = null,
       onSecondary = null,
       tone = SkillNovaTone.warning;

  const SkillNovaStatusView.error({
    super.key,
    this.title = 'Something went wrong',
    this.message =
        'We couldn’t load this right now. It’s not you — please try again.',
    this.onAction,
    this.compact = false,
  }) : icon = Icons.cloud_off_rounded,
       actionLabel = 'Try again',
       secondaryLabel = null,
       onSecondary = null,
       tone = SkillNovaTone.error;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final SkillNovaTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = switch (tone) {
      SkillNovaTone.error => colors.error,
      SkillNovaTone.warning => SkillNovaColors.warning,
      SkillNovaTone.success => SkillNovaColors.success,
      _ => colors.primary,
    };
    final iconSize = compact ? 56.0 : 72.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: SkillNovaSpacing.xl,
            vertical: compact ? SkillNovaSpacing.lg : SkillNovaSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(iconSize * 0.32),
                ),
                child: Icon(icon, color: accent, size: iconSize * 0.46),
              ),
              SizedBox(height: compact ? SkillNovaSpacing.md : SkillNovaSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleLarge,
              ),
              const SizedBox(height: SkillNovaSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: SkillNovaSpacing.lg),
                PrimaryButton(label: actionLabel!, onPressed: onAction),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: SkillNovaSpacing.xs),
                GhostButton(label: secondaryLabel!, onPressed: onSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated shimmer used by skeleton loaders. Respects reduced motion.
class SkillNovaShimmer extends StatefulWidget {
  const SkillNovaShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkillNovaShimmer> createState() => _SkillNovaShimmerState();
}

class _SkillNovaShimmerState extends State<SkillNovaShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SkillNovaMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainer;
    final highlight = Color.lerp(base, colors.surface, 0.7)!;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + 3 * t, -0.3),
            end: Alignment(-0.5 + 3 * t, 0.3),
            colors: [base, highlight, base],
            stops: const [0.1, 0.5, 0.9],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// A single skeleton block. Wrap groups of these in one [SkillNovaShimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = SkillNovaRadius.xsmall,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Generic list skeleton: avatar + two lines, repeated.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.padding});

  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: SkillNovaShimmer(
        child: ListView.separated(
          padding: padding ?? const EdgeInsets.all(SkillNovaSpacing.gutter),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: SkillNovaSpacing.md),
          itemBuilder: (_, _) => const Row(
            children: [
              SkeletonBox(width: 48, height: 48, radius: 14),
              SizedBox(width: SkillNovaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 14),
                    SizedBox(height: SkillNovaSpacing.xs),
                    SkeletonBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle press-down scale for tappable cards.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: SkillNovaMotion.of(context, SkillNovaMotion.fast),
        curve: SkillNovaMotion.standard,
        child: widget.child,
      ),
    );
  }
}
