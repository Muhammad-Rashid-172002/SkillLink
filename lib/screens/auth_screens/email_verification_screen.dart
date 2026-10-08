import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/core/auth/user_role.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/screens/auth_screens/auth_layout.dart';
import 'package:skill_link/screens/auth_screens/verification_widgets.dart';

/// Step 1 of 3 for new accounts: confirm the email address.
///
/// Verification is detected automatically (polling + when the app returns
/// to the foreground), so people don't have to tap anything after clicking
/// the link in their inbox.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.role});

  final String role;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 30;
  bool _checking = false;
  bool _sending = false;
  bool _done = false;

  UserRole get _role => UserRole.tryParse(widget.role) ?? UserRole.customer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    _runCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool manual = false}) async {
    if (_checking || _done) return;
    if (manual) setState(() => _checking = true);
    _checking = true;
    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) await SessionRouter.signOut(context);
        return;
      }
      if (user.emailVerified) {
        _done = true;
        _poll?.cancel();
        if (!mounted) return;
        SkillNovaToast.show(
          context,
          'Email verified. Nice!',
          tone: SkillNovaTone.success,
        );
        await SessionRouter.continueSession(context, selectedRole: _role);
      } else if (manual && mounted) {
        SkillNovaToast.show(
          context,
          'Not verified yet. Open the link we emailed you, then come back — '
          'we’ll continue automatically.',
          tone: SkillNovaTone.warning,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (manual && mounted) {
        SkillNovaToast.show(
          context,
          error.code == 'network-request-failed'
              ? 'You appear to be offline. Check your connection.'
              : 'We couldn’t check right now. Please try again.',
          tone: SkillNovaTone.error,
        );
      }
    } catch (error) {
      debugPrint('Email verification check error: $error');
    } finally {
      _checking = false;
      if (mounted && !_done) setState(() {});
    }
  }

  Future<void> _resend() async {
    final user = _auth.currentUser;
    if (_sending || _cooldown > 0 || user == null) return;
    setState(() => _sending = true);
    try {
      try {
        await FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('sendCustomVerificationEmail')
            .call(<String, dynamic>{
              'uid': user.uid,
              'email': (user.email ?? '').trim().toLowerCase(),
            })
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        await user.sendEmailVerification();
      }
      if (!mounted) return;
      _startCooldown(60);
      SkillNovaToast.show(
        context,
        'A new link is on its way. Check your inbox and spam folder.',
        tone: SkillNovaTone.success,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      SkillNovaToast.show(
        context,
        error.code == 'too-many-requests'
            ? 'You’ve requested several emails. Please wait a few minutes.'
            : 'We couldn’t send the email right now. Please try again.',
        tone: SkillNovaTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      SkillNovaToast.show(
        context,
        'We couldn’t send the email right now. Please try again.',
        tone: SkillNovaTone.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown(int seconds) {
    setState(() => _cooldown = seconds);
    _runCooldown();
  }

  void _runCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _auth.currentUser?.email ?? 'your email address';
    return AuthLayout(
      role: _role,
      trailing: TextButton(
        onPressed: () => SessionRouter.signOut(context),
        child: const Text('Sign out'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VerificationProgress(step: 1),
          const SizedBox(height: SkillNovaSpacing.xl),
          VerificationHeroIcon(
            icon: Icons.mark_email_unread_rounded,
            color: SkillNovaColors.roleColor(_role),
          ),
          const SizedBox(height: SkillNovaSpacing.lg),
          Text('Check your inbox', style: theme.textTheme.headlineMedium),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                const TextSpan(text: 'We sent a verification link to '),
                TextSpan(
                  text: email,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(
                  text: '. Open it on any device to confirm your address.',
                ),
              ],
            ),
          ),
          const SizedBox(height: SkillNovaSpacing.lg),
          const InfoRow(
            icon: Icons.autorenew_rounded,
            text: 'This screen updates automatically once you’re verified.',
          ),
          const InfoRow(
            icon: Icons.folder_special_outlined,
            text: 'Can’t find it? Check Spam or Promotions.',
          ),
          const SizedBox(height: SkillNovaSpacing.xl),
          PrimaryButton(
            label: 'I’ve verified my email',
            fullWidth: true,
            loading: _checking,
            onPressed: () => _check(manual: true),
          ),
          const SizedBox(height: SkillNovaSpacing.sm),
          OutlineButton(
            label: _cooldown > 0
                ? 'Resend email in ${_cooldown}s'
                : 'Resend verification email',
            icon: Icons.send_rounded,
            fullWidth: true,
            loading: _sending,
            onPressed: _cooldown > 0 ? null : _resend,
          ),
        ],
      ),
    );
  }
}
