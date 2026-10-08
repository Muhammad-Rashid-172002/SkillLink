import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/auth_session_service.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';

/// Settings > Security. Only offers what SkillNova actually supports:
/// a password reset link for email/password accounts. Google accounts manage
/// their password with Google.
class SecuritySettingsSection extends StatefulWidget {
  const SecuritySettingsSection({super.key, this.hasPassword, this.email});

  /// Test overrides; default to the signed-in account.
  final bool? hasPassword;
  final String? email;

  @override
  State<SecuritySettingsSection> createState() =>
      _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends State<SecuritySettingsSection> {
  bool _sending = false;

  bool get _hasPassword =>
      widget.hasPassword ?? AuthSessionService.instance.hasPasswordSignIn;

  String? get _email {
    if (widget.email != null) return widget.email;
    try {
      return FirebaseAuth.instance.currentUser?.email;
    } catch (_) {
      return null; // Firebase not initialised (e.g. widget tests).
    }
  }

  Future<void> _resetPassword() async {
    final email = _email;
    if (email == null || email.isEmpty || _sending) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.lock_reset_rounded),
        title: const Text('Change your password?'),
        content: Text(
          'We’ll email a secure link to $email. Open it to choose a new '
          'password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await AuthSessionService.instance.sendPasswordReset(email);
      if (mounted) {
        SkillNovaToast.show(
          context,
          'Check $email for your reset link.',
          tone: SkillNovaTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        SkillNovaToast.show(
          context,
          'We couldn’t send the link right now. Please try again.',
          tone: SkillNovaTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Security',
      children: [
        if (_hasPassword)
          ProfileMenuTile(
            key: const Key('change-password'),
            icon: Icons.lock_reset_rounded,
            title: _sending ? 'Sending link…' : 'Change password',
            subtitle: 'Get a secure reset link by email',
            onTap: _sending ? null : _resetPassword,
          )
        else
          const ProfileMenuTile(
            icon: Icons.account_circle_outlined,
            title: 'Signed in with Google',
            subtitle: 'Manage your password in your Google account',
          ),
      ],
    );
  }
}
