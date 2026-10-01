import 'package:flutter/material.dart';
import 'package:skill_link/core/auth/auth_session_service.dart';
import 'package:skill_link/core/auth/user_role.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/auth_screens/email_verification_screen.dart';
import 'package:skill_link/screens/auth_screens/phone_verification_screen.dart';
import 'package:skill_link/screens/auth_screens/session_screens.dart';
import 'package:skill_link/screens/customer_screens/navigation/customer_navigation_shell.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_setup_screen.dart';
import 'package:skill_link/screens/onboarding_screen/OnboardingScreen.dart';
import 'package:skill_link/screens/verification/worker_verification_center.dart';
import 'package:skill_link/screens/worker_screens/navigation/worker_navigation_shell.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_setup.dart';
import 'package:skill_link/services/skillnova_preferences.dart';

/// The only place that maps a session state to a screen.
///
/// Splash, login, sign-up, Google sign-in, every verification step, profile
/// setup and logout all call into here, so role-based routing cannot drift
/// between screens again.
abstract final class SessionRouter {
  static AuthSessionService get _service => AuthSessionService.instance;

  static Widget screenFor(SessionSnapshot session) {
    final role = session.role ?? UserRole.customer;
    return switch (session.stage) {
      SessionStage.signedOut =>
        skillNovaPreferences.onboardingCompleted
            ? RoleSelectionScreen(notice: session.message)
            : const OnboardingScreen(),
      SessionStage.emailVerification => EmailVerificationScreen(
        role: role.value,
      ),
      SessionStage.phoneVerification => PhoneVerificationScreen(
        role: role.value,
      ),
      SessionStage.profileSetup =>
        role.isWorker
            ? const WorkerProfileSetupScreen()
            : const CustomerProfileSetupScreen(),
      SessionStage.workerVerification => const RoleGate(
        role: UserRole.worker,
        child: WorkerVerificationCenterScreen(),
      ),
      SessionStage.home =>
        role.isWorker
            ? const RoleGate(
                role: UserRole.worker,
                child: WorkerNavigationShell(),
              )
            : const RoleGate(
                role: UserRole.customer,
                child: CustomerNavigationShell(),
              ),
      SessionStage.roleRequired => const RoleRecoveryScreen(),
      SessionStage.restricted => SessionIssueScreen(
        title: 'Account unavailable',
        message: session.message ?? 'This account cannot be used right now.',
        icon: Icons.lock_outline_rounded,
        restricted: true,
      ),
      SessionStage.error => SessionIssueScreen(
        title: 'We couldn’t load your account',
        message:
            session.message ??
            'Please check your connection and try again in a moment.',
        icon: Icons.cloud_off_rounded,
      ),
    };
  }

  /// Resolves the current session and replaces the whole stack with the right
  /// destination. [selectedRole] only helps recover legacy accounts.
  static Future<SessionSnapshot> continueSession(
    BuildContext context, {
    UserRole? selectedRole,
  }) async {
    final session = await _service.resolve(selectedRole: selectedRole);
    if (context.mounted) go(context, session);
    return session;
  }

  static void go(BuildContext context, SessionSnapshot session) {
    replaceAll(context, screenFor(session));
  }

  static void replaceAll(BuildContext context, Widget screen) {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      PageRouteBuilder<void>(
        transitionDuration: SkillNovaMotion.of(context, SkillNovaMotion.slow),
        reverseTransitionDuration: SkillNovaMotion.of(
          context,
          SkillNovaMotion.medium,
        ),
        pageBuilder: (_, _, _) => screen,
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: SkillNovaMotion.standard,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
      (_) => false,
    );
  }

  /// Clean logout used by every "Log out" button.
  static Future<void> signOut(BuildContext context) async {
    await _service.signOut();
    if (!context.mounted) return;
    replaceAll(context, const RoleSelectionScreen());
  }
}

/// Protects a role-specific area.
///
/// The role is verified against Firestore by [AuthSessionService.resolve]; if
/// someone reaches this widget with a different (or unverified) role — for
/// example via a stale deep link — they are re-routed to where they belong.
/// Firestore security rules enforce the same boundary on the server.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key, required this.role, required this.child});

  final UserRole role;
  final Widget child;

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final AuthSessionService _service = AuthSessionService.instance;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _service.verifiedRole.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _service.verifiedRole.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted || _redirecting || _service.isSigningOut) return;
    final verified = _service.verifiedRole.value;
    if (verified == widget.role) return;
    if (_service.currentUser == null && verified == null) {
      _redirecting = true;
      SessionRouter.replaceAll(context, const RoleSelectionScreen());
      return;
    }
    if (verified == null) {
      // Not yet verified in this process (e.g. opened from a notification).
      final session = await _service.resolve();
      if (!mounted) return;
      if (session.role == widget.role &&
          (session.stage == SessionStage.home ||
              session.stage == SessionStage.workerVerification)) {
        return;
      }
      _redirecting = true;
      SessionRouter.go(context, session);
      return;
    }
    _redirecting = true;
    await SessionRouter.continueSession(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserRole?>(
      valueListenable: _service.verifiedRole,
      builder: (context, verified, child) {
        if (verified == widget.role) return child!;
        return const Scaffold(
          body: Center(child: CircularProgressIndicator.adaptive()),
        );
      },
      child: widget.child,
    );
  }
}
