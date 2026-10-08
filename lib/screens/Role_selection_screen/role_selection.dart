import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/user_role.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/screens/auth_screens/auth_layout.dart';
import 'package:skill_link/screens/auth_screens/auth_screen.dart';
import 'package:skill_link/screens/auth_screens/session_screens.dart';

/// Entry point for signed-out people: choose how you'll use SkillNova.
///
/// The choice decides which account type is *created* at sign-up. For sign-in
/// the stored account role always wins, so picking the "wrong" card can never
/// lock anybody out.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, this.notice});

  /// Optional message to show once (e.g. "Your session has expired").
  final String? notice;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selected = UserRole.customer;

  @override
  void initState() {
    super.initState();
    final notice = widget.notice;
    if (notice != null && notice.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SkillNovaToast.show(context, notice, tone: SkillNovaTone.info);
        }
      });
    }
  }

  void _continue({required bool signIn}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(role: _selected.value, startInLogin: signIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthLayout(
      role: _selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!AuthLayout.showsBrandPanel(context)) ...[
            const SkillNovaWordmark(size: 32),
            const SizedBox(height: SkillNovaSpacing.xxl),
          ],
          Text(
            'How will you use SkillNova?',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text(
            'Pick one to get started. You can always reach us if you need '
            'to change it later.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SkillNovaSpacing.xl),
          RoleChoiceTile(
            role: UserRole.customer,
            title: 'I need a service',
            subtitle:
                'Request help at home, compare professionals and track the job.',
            icon: Icons.person_search_rounded,
            highlights: const [
              'Post requests',
              'Compare pros',
              'Live tracking',
            ],
            selected: _selected == UserRole.customer,
            onTap: () => setState(() => _selected = UserRole.customer),
          ),
          const SizedBox(height: SkillNovaSpacing.sm),
          RoleChoiceTile(
            role: UserRole.worker,
            title: 'I offer a service',
            subtitle:
                'Receive nearby job leads, manage your work and grow your income.',
            icon: Icons.handyman_rounded,
            highlights: const ['Nearby leads', 'Job manager', 'Earnings'],
            selected: _selected == UserRole.worker,
            onTap: () => setState(() => _selected = UserRole.worker),
          ),
          const SizedBox(height: SkillNovaSpacing.xl),
          PrimaryButton(
            label: 'Create ${_selected.label.toLowerCase()} account',
            fullWidth: true,
            onPressed: () => _continue(signIn: false),
          ),
          const SizedBox(height: SkillNovaSpacing.sm),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: theme.textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: () => _continue(signIn: true),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
