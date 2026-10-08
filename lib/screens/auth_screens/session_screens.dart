import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/auth_session_service.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/core/auth/user_role.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_support_screens.dart';

/// Shown only when an existing account has no recoverable role at all
/// (no `role`, no legacy field, no profile evidence, no device record).
/// Instead of the old dead-end "Account role is invalid" error, the person
/// confirms their account type once and it is saved permanently.
class RoleRecoveryScreen extends StatefulWidget {
  const RoleRecoveryScreen({super.key});

  @override
  State<RoleRecoveryScreen> createState() => _RoleRecoveryScreenState();
}

class _RoleRecoveryScreenState extends State<RoleRecoveryScreen> {
  UserRole? _selected;
  bool _saving = false;

  Future<void> _save() async {
    final role = _selected;
    if (role == null || _saving) return;
    setState(() => _saving = true);
    try {
      await AuthSessionService.instance.assignMissingRole(role);
      if (!mounted) return;
      await SessionRouter.continueSession(context);
    } on SessionException catch (error) {
      if (!mounted) return;
      SkillNovaToast.show(context, error.message, tone: SkillNovaTone.error);
    } catch (_) {
      if (!mounted) return;
      SkillNovaToast.show(
        context,
        'We couldn’t save that right now. Check your connection and try again.',
        tone: SkillNovaTone.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = AuthSessionService.instance.currentUser?.email;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SkillNovaSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: SkillNovaBreakpoints.maxReadableWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkillNovaLogo(size: 48, framed: true),
                  const SizedBox(height: SkillNovaSpacing.xl),
                  Text(
                    'One last detail',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: SkillNovaSpacing.xs),
                  Text(
                    email == null
                        ? 'Tell us how you use SkillNova so we can open the right workspace.'
                        : 'Tell us how you use SkillNova with $email so we can open the right workspace. You’ll only be asked once.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SkillNovaSpacing.xl),
                  RoleChoiceTile(
                    role: UserRole.customer,
                    title: 'I need services',
                    subtitle:
                        'Find, book and track trusted local professionals.',
                    icon: Icons.person_search_rounded,
                    selected: _selected == UserRole.customer,
                    onTap: () => setState(() => _selected = UserRole.customer),
                  ),
                  const SizedBox(height: SkillNovaSpacing.sm),
                  RoleChoiceTile(
                    role: UserRole.worker,
                    title: 'I offer services',
                    subtitle: 'Get job leads nearby, manage work and earnings.',
                    icon: Icons.handyman_rounded,
                    selected: _selected == UserRole.worker,
                    onTap: () => setState(() => _selected = UserRole.worker),
                  ),
                  const SizedBox(height: SkillNovaSpacing.xl),
                  PrimaryButton(
                    label: 'Continue',
                    fullWidth: true,
                    loading: _saving,
                    onPressed: _selected == null ? null : _save,
                  ),
                  const SizedBox(height: SkillNovaSpacing.xs),
                  GhostButton(
                    label: 'Use a different account',
                    fullWidth: true,
                    onPressed: _saving
                        ? null
                        : () => SessionRouter.signOut(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Error / restricted states during session restore. Never logs people out
/// just because the network blinked.
class SessionIssueScreen extends StatefulWidget {
  const SessionIssueScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.restricted = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final bool restricted;

  @override
  State<SessionIssueScreen> createState() => _SessionIssueScreenState();
}

class _SessionIssueScreenState extends State<SessionIssueScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final session = await AuthSessionService.instance.resolve();
    if (!mounted) return;
    if (session.stage == SessionStage.error) {
      setState(() => _retrying = false);
      SkillNovaToast.show(
        context,
        'Still can’t connect. We’ll keep your session — try again shortly.',
        tone: SkillNovaTone.warning,
      );
      return;
    }
    SessionRouter.go(context, session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SkillNovaStatusView(
                icon: widget.icon,
                title: widget.title,
                message: widget.message,
                tone: widget.restricted
                    ? SkillNovaTone.warning
                    : SkillNovaTone.error,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SkillNovaSpacing.xl,
                0,
                SkillNovaSpacing.xl,
                SkillNovaSpacing.xl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    if (widget.restricted)
                      PrimaryButton(
                        label: 'Contact support',
                        icon: Icons.support_agent_rounded,
                        fullWidth: true,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const HelpSupportScreen(),
                          ),
                        ),
                      )
                    else
                      PrimaryButton(
                        label: 'Try again',
                        icon: Icons.refresh_rounded,
                        fullWidth: true,
                        loading: _retrying,
                        onPressed: _retry,
                      ),
                    const SizedBox(height: SkillNovaSpacing.xs),
                    GhostButton(
                      label: widget.restricted
                          ? 'Back to sign in'
                          : 'Sign in with another account',
                      fullWidth: true,
                      onPressed: _retrying
                          ? null
                          : () async {
                              if (widget.restricted) {
                                SessionRouter.replaceAll(
                                  context,
                                  const RoleSelectionScreen(),
                                );
                              } else {
                                await SessionRouter.signOut(context);
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large selectable card used by role selection and role recovery.
class RoleChoiceTile extends StatelessWidget {
  const RoleChoiceTile({
    super.key,
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.highlights = const [],
  });

  final UserRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = SkillNovaColors.roleColor(role);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '${role.label}: $title. $subtitle',
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        scale: 0.985,
        child: AnimatedContainer(
          duration: SkillNovaMotion.of(context, SkillNovaMotion.medium),
          curve: SkillNovaMotion.standard,
          padding: const EdgeInsets.all(SkillNovaSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.16 : 0.06)
                : colors.surface,
            borderRadius: BorderRadius.circular(SkillNovaRadius.large),
            border: Border.all(
              color: selected ? accent : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? SkillNovaElevation.subtle : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.22 : 0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: SkillNovaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(title, style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: SkillNovaMotion.of(context, SkillNovaMotion.fast),
                    child: selected
                        ? Icon(
                            Icons.check_circle_rounded,
                            key: const ValueKey('on'),
                            color: accent,
                            size: 26,
                          )
                        : Icon(
                            Icons.radio_button_unchecked_rounded,
                            key: const ValueKey('off'),
                            color: colors.outline,
                            size: 26,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: SkillNovaSpacing.sm),
              Text(subtitle, style: theme.textTheme.bodyMedium),
              if (highlights.isNotEmpty) ...[
                const SizedBox(height: SkillNovaSpacing.sm),
                Wrap(
                  spacing: SkillNovaSpacing.xs,
                  runSpacing: SkillNovaSpacing.xs,
                  children: [
                    for (final item in highlights)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            SkillNovaRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 14, color: accent),
                            const SizedBox(width: 4),
                            Text(
                              item,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
