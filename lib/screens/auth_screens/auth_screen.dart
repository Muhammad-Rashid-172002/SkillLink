import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/core/auth/auth_errors.dart';
import 'package:skill_link/core/auth/auth_session_service.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/core/auth/user_role.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_text_field.dart';
import 'package:skill_link/screens/auth_screens/auth_layout.dart';
import 'package:skill_link/screens/shared/skillnova_about.dart';
import 'package:skill_link/services/saveFcmToken.dart';

/// Sign in / create account for customers and workers.
///
/// All routing after authentication goes through [SessionRouter], which reads
/// the role stored on the account. [role] only decides the type of a *new*
/// account (and helps recover legacy accounts that have no stored role).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.role, this.startInLogin = false});

  final String role;
  final bool startInLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthSessionService _session = AuthSessionService.instance;

  late bool _isLogin = widget.startInLogin;
  bool _acceptTerms = false;
  bool _termsError = false;
  bool _busy = false;
  bool _googleBusy = false;
  String? _formError;

  UserRole get _role => UserRole.tryParse(widget.role) ?? UserRole.customer;
  Color get _accent => SkillNovaColors.roleColor(_role);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!_isLogin && !_acceptTerms) {
      setState(() => _termsError = true);
    }
    if (!valid || (!_isLogin && !_acceptTerms) || _busy) return;

    setState(() => _busy = true);
    try {
      if (_isLogin) {
        await _login();
      } else {
        await _signUp();
      }
    } on FirebaseAuthException catch (error) {
      _showFormError(AuthErrors.forAuthCode(error.code));
    } on FirebaseException catch (error) {
      _showFormError(AuthErrors.forFirestoreCode(error.code));
    } catch (error) {
      debugPrint('Auth submit error: $error');
      _showFormError(AuthErrors.generic);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    unawaited(saveFcmToken());
    await _routeAfterAuth();
  }

  Future<void> _signUp() async {
    final role = _role;
    await _session.rememberPendingRole(role);

    final credential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-creation-failed');
    }

    final name = _nameController.text.trim();
    try {
      await user.updateDisplayName(name);
    } catch (_) {
      // Display name is cosmetic; the Firestore profile holds the real name.
    }

    try {
      await _session.createProfile(user: user, role: role, name: name);
    } on FirebaseException catch (error) {
      // The auth account exists; the session resolver recreates the profile
      // from the remembered role on the next step, so don't strand the user.
      debugPrint('Profile write deferred: ${error.code}');
    }

    unawaited(saveFcmToken());
    await _sendVerificationEmail(user);
    await _routeAfterAuth();
  }

  Future<void> _sendVerificationEmail(User user) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendCustomVerificationEmail')
          .call(<String, dynamic>{
            'uid': user.uid,
            'email': (user.email ?? _emailController.text).trim().toLowerCase(),
          })
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      debugPrint('Custom verification email failed, falling back: $error');
      try {
        await user.sendEmailVerification();
      } catch (fallbackError) {
        debugPrint('Verification email fallback failed: $fallbackError');
        // The verification screen offers "Resend", so continue.
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;
    setState(() {
      _busy = true;
      _googleBusy = true;
      _formError = null;
    });

    try {
      final google = GoogleSignIn.instance;
      await _session.ensureGoogleInitialized();
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(code: 'google-token-missing');
      }
      final result = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      final user = result.user;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final snapshot = await reference.get();
      if (!snapshot.exists) {
        await _session.createProfile(
          user: user,
          role: _role,
          name: user.displayName ?? account.displayName,
          authProvider: 'google',
        );
      } else {
        await reference.set({
          'photoUrl': user.photoURL ?? snapshot.data()?['photoUrl'],
          'emailVerified': true,
          'lastSignInProvider': 'google',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      unawaited(saveFcmToken());
      await _routeAfterAuth();
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showFormError(
          'Google sign-in couldn’t be completed. Please try again, or use '
          'your email and password.',
        );
      }
    } on FirebaseAuthException catch (error) {
      _showFormError(AuthErrors.forAuthCode(error.code));
    } on FirebaseException catch (error) {
      _showFormError(AuthErrors.forFirestoreCode(error.code));
    } catch (error) {
      debugPrint('Google sign-in error: $error');
      _showFormError(
        'Google sign-in isn’t available on this device right now. '
        'Please use your email and password.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _googleBusy = false;
        });
      }
    }
  }

  /// Resolves the account's stored role and opens the right place.
  Future<void> _routeAfterAuth() async {
    final session = await _session.resolve(selectedRole: _role);
    if (!mounted) return;

    if (session.stage == SessionStage.error) {
      _showFormError(session.message ?? AuthErrors.generic);
      return;
    }

    final storedRole = session.role;
    if (_isLogin &&
        storedRole != null &&
        storedRole != _role &&
        storedRole.isAppRole) {
      SkillNovaToast.show(
        context,
        'Signed in to your ${storedRole.label.toLowerCase()} account.',
        tone: SkillNovaTone.info,
      );
    }
    SessionRouter.go(context, session);
  }

  Future<void> _forgotPassword() async {
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResetPasswordSheet(initialEmail: _emailController.text),
    );
    if (email == null || !mounted) return;
    SkillNovaToast.show(
      context,
      'If an account exists for $email, a reset link is on its way. '
      'Check your inbox and spam folder.',
      tone: SkillNovaTone.success,
      duration: const Duration(seconds: 6),
    );
  }

  void _showFormError(String message) {
    if (!mounted) return;
    setState(() => _formError = message);
  }

  void _switchMode(bool login) {
    if (_busy || _isLogin == login) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLogin = login;
      _formError = null;
      _termsError = false;
      _formKey.currentState?.reset();
    });
  }

  void _openLegal(String title, Uri? url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, url: url),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AuthLayout(
      role: _role,
      showBack: Navigator.of(context).canPop(),
      busy: _busy,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RolePill(role: _role),
              const SizedBox(height: SkillNovaSpacing.md),
              AnimatedSwitcher(
                duration: SkillNovaMotion.of(context, SkillNovaMotion.medium),
                child: Column(
                  key: ValueKey(_isLogin),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLogin ? 'Welcome back' : 'Create your account',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: SkillNovaSpacing.xs),
                    Text(
                      _isLogin
                          ? 'Sign in to continue to SkillNova.'
                          : _role.isWorker
                          ? 'Join as a professional and start receiving job leads near you.'
                          : 'Book trusted local professionals in a few taps.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SkillNovaSpacing.xl),
              _ModeSwitch(
                isLogin: _isLogin,
                accent: _accent,
                onChanged: _switchMode,
              ),
              const SizedBox(height: SkillNovaSpacing.xl),
              AnimatedSize(
                duration: SkillNovaMotion.of(context, SkillNovaMotion.medium),
                curve: SkillNovaMotion.standard,
                alignment: Alignment.topCenter,
                child: _isLogin
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(
                          bottom: SkillNovaSpacing.md,
                        ),
                        child: SkillNovaTextField(
                          label: 'Full name',
                          controller: _nameController,
                          hint: 'e.g. Ayesha Khan',
                          prefixIcon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          onSubmitted: (_) => _emailFocus.requestFocus(),
                          validator: AuthValidators.name,
                        ),
                      ),
              ),
              SkillNovaTextField(
                label: 'Email',
                controller: _emailController,
                focusNode: _emailFocus,
                hint: 'you@example.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                validator: AuthValidators.email,
              ),
              const SizedBox(height: SkillNovaSpacing.md),
              SkillNovaTextField(
                label: 'Password',
                controller: _passwordController,
                focusNode: _passwordFocus,
                hint: _isLogin ? 'Your password' : 'At least 8 characters',
                prefixIcon: Icons.lock_outline_rounded,
                obscure: true,
                helper: _isLogin
                    ? null
                    : 'Use 8+ characters with a mix of letters and numbers.',
                textInputAction: TextInputAction.done,
                autofillHints: [
                  _isLogin ? AutofillHints.password : AutofillHints.newPassword,
                ],
                onSubmitted: (_) => _submit(),
                validator: _isLogin
                    ? AuthValidators.loginPassword
                    : AuthValidators.newPassword,
              ),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                )
              else ...[
                const SizedBox(height: SkillNovaSpacing.md),
                _TermsCheckbox(
                  value: _acceptTerms,
                  showError: _termsError && !_acceptTerms,
                  onChanged: (value) => setState(() {
                    _acceptTerms = value;
                    if (value) _termsError = false;
                  }),
                  onTerms: () => _openLegal(
                    'Terms of Service',
                    SkillNovaSupportConfig.termsOfServiceUrl,
                  ),
                  onPrivacy: () => _openLegal(
                    'Privacy Policy',
                    SkillNovaSupportConfig.privacyPolicyUrl,
                  ),
                ),
              ],
              AnimatedSize(
                duration: SkillNovaMotion.of(context, SkillNovaMotion.medium),
                child: _formError == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(
                          top: SkillNovaSpacing.md,
                        ),
                        child: _ErrorBanner(message: _formError!),
                      ),
              ),
              const SizedBox(height: SkillNovaSpacing.lg),
              PrimaryButton(
                label: _isLogin ? 'Sign in' : 'Create account',
                fullWidth: true,
                loading: _busy && !_googleBusy,
                onPressed: _submit,
              ),
              const SizedBox(height: SkillNovaSpacing.lg),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: theme.textTheme.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: SkillNovaSpacing.lg),
              _GoogleButton(
                loading: _googleBusy,
                onPressed: _busy ? null : _signInWithGoogle,
              ),
              const SizedBox(height: SkillNovaSpacing.lg),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _isLogin
                          ? 'New to SkillNova?'
                          : 'Already have an account?',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => _switchMode(!_isLogin),
                      child: Text(_isLogin ? 'Create an account' : 'Sign in'),
                    ),
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

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = SkillNovaColors.roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            role.isWorker ? Icons.handyman_rounded : Icons.person_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            role.isWorker ? 'Worker account' : 'Customer account',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({
    required this.isLogin,
    required this.accent,
    required this.onChanged,
  });

  final bool isLogin;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Create account')),
          ButtonSegment(value: true, label: Text('Sign in')),
        ],
        selected: {isLogin},
        onSelectionChanged: (value) => onChanged(value.first),
        style: SegmentedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          selectedBackgroundColor: accent.withValues(alpha: 0.12),
          selectedForegroundColor: accent,
          textStyle: Theme.of(context).textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.showError,
    required this.onChanged,
    required this.onTerms,
    required this.onPrivacy,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              isError: showError,
              onChanged: (checked) => onChanged(checked ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => onChanged(!value),
                      child: Text(
                        'I agree to the ',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    InkWell(
                      onTap: onTerms,
                      child: Text('Terms of Service', style: linkStyle),
                    ),
                    Text(' and ', style: theme.textTheme.bodyMedium),
                    InkWell(
                      onTap: onPrivacy,
                      child: Text('Privacy Policy', style: linkStyle),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              'Please accept the terms to create your account.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SkillNovaSpacing.sm),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
          border: Border.all(color: colors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: colors.error, size: 20),
            const SizedBox(width: SkillNovaSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleMark(),
                  const SizedBox(width: SkillNovaSpacing.sm),
                  Text(
                    'Continue with Google',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Four-colour "G" drawn without bundling a third-party asset.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ShaderMask(
        shaderCallback: (bounds) => const SweepGradient(
          colors: [
            Color(0xFFEA4335),
            Color(0xFFFBBC05),
            Color(0xFF34A853),
            Color(0xFF4285F4),
            Color(0xFFEA4335),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(bounds),
        child: const Text(
          'G',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false) || _sending) return;
    final email = _email.text.trim().toLowerCase();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      try {
        await FirebaseFunctions.instanceFor(region: 'us-central1')
            .httpsCallable('sendCustomPasswordResetEmail')
            .call(<String, dynamic>{'email': email})
            .timeout(const Duration(seconds: 20));
      } on FirebaseFunctionsException catch (error) {
        if (error.code == 'invalid-argument') rethrow;
        // Branded email unavailable: fall back to Firebase's built-in email.
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      } on TimeoutException {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }
      if (mounted) Navigator.of(context).pop(email);
    } on FirebaseAuthException catch (error) {
      setState(() => _error = AuthErrors.forAuthCode(error.code));
    } catch (_) {
      setState(
        () => _error =
            'We couldn’t send the reset email right now. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SkillNovaSpacing.xl,
        0,
        SkillNovaSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + SkillNovaSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset your password', style: theme.textTheme.titleLarge),
            const SizedBox(height: SkillNovaSpacing.xs),
            Text(
              'Enter the email you signed up with and we’ll send you a link '
              'to choose a new password.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: SkillNovaSpacing.lg),
            SkillNovaTextField(
              label: 'Email',
              controller: _email,
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autofocus: widget.initialEmail.trim().isEmpty,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              validator: AuthValidators.email,
            ),
            if (_error != null) ...[
              const SizedBox(height: SkillNovaSpacing.sm),
              _ErrorBanner(message: _error!),
            ],
            const SizedBox(height: SkillNovaSpacing.lg),
            PrimaryButton(
              label: 'Send reset link',
              fullWidth: true,
              loading: _sending,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
