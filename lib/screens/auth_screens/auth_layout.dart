import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/user_role.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';

/// Shared responsive frame for every signed-out / verification screen.
///
/// * Phones: a single scrollable column with comfortable gutters.
/// * Tablets & desktop/web: a brand panel on the left and the form on the
///   right, instead of a stretched phone layout.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.child,
    this.role,
    this.showBack = false,
    this.onBack,
    this.trailing,
    this.busy = false,
  });

  final Widget child;
  final UserRole? role;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Blocks interaction (but keeps the form visible) while work is running.
  final bool busy;

  /// Whether the two-pane layout (brand panel + form) is used. Landscape
  /// phones are wide but short, so they keep the single scrolling column
  /// instead of squeezing a brand panel into ~390px of height.
  static bool showsBrandPanel(BuildContext context) =>
      SkillNovaBreakpoints.isWide(context) &&
      MediaQuery.sizeOf(context).height >= 560;

  @override
  Widget build(BuildContext context) {
    final wide = showsBrandPanel(context);
    final topBar = (showBack || trailing != null)
        ? Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                if (showBack)
                  IconButton(
                    tooltip: 'Back',
                    onPressed: busy
                        ? null
                        : onBack ?? () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                const Spacer(),
                ?trailing,
              ],
            ),
          )
        : const SizedBox(height: 8);

    final form = SafeArea(
      child: Column(
        children: [
          topBar,
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  SkillNovaSpacing.xl,
                  wide ? SkillNovaSpacing.xxl : SkillNovaSpacing.xs,
                  SkillNovaSpacing.xl,
                  SkillNovaSpacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: AbsorbPointer(absorbing: busy, child: child),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                Expanded(flex: 5, child: _BrandPanel(role: role)),
                Expanded(flex: 6, child: form),
              ],
            )
          : form,
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.role});

  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWorker = role == UserRole.worker;
    final headline = isWorker
        ? 'Grow your business with local customers.'
        : 'Get things fixed by people you can trust.';
    final points = isWorker
        ? const [
            (Icons.radar_rounded, 'Job leads from customers near you'),
            (Icons.verified_user_rounded, 'A verified profile customers trust'),
            (
              Icons.account_balance_wallet_rounded,
              'Jobs and earnings in one place',
            ),
          ]
        : const [
            (Icons.search_rounded, 'Find skilled professionals nearby'),
            (Icons.verified_rounded, 'Identity-verified workers'),
            (Icons.route_rounded, 'Track every job from request to done'),
          ];

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SkillNovaColors.inkGradient),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            bottom: -120,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    SkillNovaColors.roleColor(role).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            // Scrolls (instead of overflowing) on short windows while the
            // Spacers still distribute free space on tall ones.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkillNovaWordmark(
                            size: 36,
                            color: Colors.white,
                          ),
                          const Spacer(),
                          AnimatedSwitcher(
                            duration: SkillNovaMotion.medium,
                            child: Text(
                              headline,
                              key: ValueKey(headline),
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: SkillNovaSpacing.xl),
                          for (final (icon, text) in points)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 19,
                                      color: const Color(0xFF7DD3FC),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Text(
                            '© SkillNova',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
