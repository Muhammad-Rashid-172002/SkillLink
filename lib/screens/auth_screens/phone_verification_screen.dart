import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/core/auth/user_role.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_text_field.dart';
import 'package:skill_link/screens/auth_screens/auth_layout.dart';
import 'package:skill_link/screens/auth_screens/verification_widgets.dart';

/// Step 2 of 3: link and verify a Pakistani mobile number with an SMS code.
class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key, required this.role});

  final String role;

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();

  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmation;
  String? _phone;
  bool _sending = false;
  bool _verifying = false;
  bool _completed = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  UserRole get _role => UserRole.tryParse(widget.role) ?? UserRole.customer;
  bool get _codeSent => _verificationId != null || _webConfirmation != null;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  /// Accepts 03XXXXXXXXX, 3XXXXXXXXX, 923XXXXXXXXX, +923XXXXXXXXX, 00923...
  static String? normalizePakistanPhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.startsWith('0092')) phone = '+92${phone.substring(4)}';
    if (phone.startsWith('92')) phone = '+$phone';
    if (phone.startsWith('03')) phone = '+92${phone.substring(1)}';
    if (RegExp(r'^3\d{9}$').hasMatch(phone)) phone = '+92$phone';
    return RegExp(r'^\+923\d{9}$').hasMatch(phone) ? phone : null;
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_sending || _verifying) return;
    if (!resend && !(_phoneFormKey.currentState?.validate() ?? false)) return;
    final phone = resend ? _phone : normalizePakistanPhone(_phoneController.text);
    if (phone == null) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        final user = _auth.currentUser;
        if (user == null) throw FirebaseAuthException(code: 'user-not-found');
        final confirmation = await user.linkWithPhoneNumber(phone);
        _onCodeSent(phone, webConfirmation: confirmation);
        return;
      }
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: resend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) => _complete(credential, phone),
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() {
            _sending = false;
            _error = _messageFor(error.code);
          });
        },
        codeSent: (verificationId, resendToken) {
          _resendToken = resendToken;
          _onCodeSent(phone, verificationId: verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId ??= verificationId;
          if (mounted) setState(() => _sending = false);
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _messageFor(error.code);
      });
    } catch (error) {
      debugPrint('Phone verification send error: $error');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'We couldn’t send the code right now. Please try again.';
      });
    }
  }

  void _onCodeSent(
    String phone, {
    String? verificationId,
    ConfirmationResult? webConfirmation,
  }) {
    if (!mounted) return;
    setState(() {
      _verificationId = verificationId;
      _webConfirmation = webConfirmation;
      _phone = phone;
      _sending = false;
      _otpController.clear();
      _resendIn = 60;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 60));
      if (_resendIn == 0) timer.cancel();
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    final phone = _phone;
    if (phone == null || _verifying) return;
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the SMS.');
      return;
    }
    if (_webConfirmation != null) {
      setState(() {
        _verifying = true;
        _error = null;
      });
      try {
        await _webConfirmation!.confirm(code);
        await _markVerified(phone);
      } on FirebaseAuthException catch (error) {
        if (mounted) {
          setState(() {
            _verifying = false;
            _error = _messageFor(error.code);
          });
        }
      }
      return;
    }
    final id = _verificationId;
    if (id == null) return;
    await _complete(
      PhoneAuthProvider.credential(verificationId: id, smsCode: code),
      phone,
    );
  }

  Future<void> _complete(PhoneAuthCredential credential, String phone) async {
    if (_verifying || _completed) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');
      try {
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'provider-already-linked') {
          await user.updatePhoneNumber(credential);
        } else {
          rethrow;
        }
      }
      await _markVerified(phone);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = _messageFor(error.code);
      });
    } catch (error) {
      debugPrint('Phone verification error: $error');
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'We couldn’t verify that code. Please try again.';
      });
    }
  }

  Future<void> _markVerified(String phone) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'phoneNumber': phone,
      'phone': phone,
      'phoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _completed = true;
    _resendTimer?.cancel();
    if (!mounted) return;
    SkillNovaToast.show(
      context,
      'Phone number verified.',
      tone: SkillNovaTone.success,
    );
    await SessionRouter.continueSession(context, selectedRole: _role);
  }

  String _messageFor(String code) => switch (code) {
    'invalid-phone-number' =>
      'That number doesn’t look right. Use a Pakistani mobile number like '
          '0300 1234567.',
    'invalid-verification-code' =>
      'That code is incorrect. Check the SMS and try again.',
    'session-expired' || 'code-expired' =>
      'That code has expired. Tap “Resend code” to get a new one.',
    'network-request-failed' =>
      'You appear to be offline. Check your connection and try again.',
    'too-many-requests' =>
      'Too many attempts. For your security, please wait a few minutes.',
    'quota-exceeded' =>
      'SMS verification is busy right now. Please try again shortly.',
    'credential-already-in-use' || 'account-exists-with-different-credential' =>
      'This number is already linked to another SkillNova account. Use a '
          'different number or contact support.',
    _ => 'We couldn’t verify your number right now. Please try again.',
  };

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _verificationId = null;
      _webConfirmation = null;
      _otpController.clear();
      _error = null;
      _resendIn = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthLayout(
      role: _role,
      busy: _verifying,
      trailing: TextButton(
        onPressed: () => SessionRouter.signOut(context),
        child: const Text('Sign out'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VerificationProgress(step: 2),
          const SizedBox(height: SkillNovaSpacing.xl),
          VerificationHeroIcon(
            icon: _codeSent ? Icons.sms_rounded : Icons.smartphone_rounded,
            color: SkillNovaColors.roleColor(_role),
          ),
          const SizedBox(height: SkillNovaSpacing.lg),
          Text(
            _codeSent ? 'Enter the code' : 'Add your mobile number',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text(
            _codeSent
                ? 'We sent a 6-digit code to $_phone.'
                : _role.isWorker
                ? 'Customers and SkillNova use it to reach you about jobs. '
                      'We’ll text you a code to confirm it.'
                : 'Professionals use it to coordinate your job. We’ll text '
                      'you a code to confirm it.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SkillNovaSpacing.xl),
          AnimatedSwitcher(
            duration: SkillNovaMotion.of(context, SkillNovaMotion.medium),
            child: _codeSent ? _buildCodeStep(theme) : _buildPhoneStep(),
          ),
          if (_error != null) ...[
            const SizedBox(height: SkillNovaSpacing.md),
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SkillNovaSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey('phone'),
        children: [
          SkillNovaTextField(
            label: 'Mobile number',
            controller: _phoneController,
            hint: '0300 1234567',
            prefixIcon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              LengthLimitingTextInputFormatter(16),
            ],
            helper: 'Pakistani mobile numbers only for now.',
            onSubmitted: (_) => _sendCode(),
            validator: (value) => normalizePakistanPhone(value ?? '') == null
                ? 'Enter a valid mobile number, like 0300 1234567.'
                : null,
          ),
          const SizedBox(height: SkillNovaSpacing.xl),
          PrimaryButton(
            label: 'Send code',
            fullWidth: true,
            loading: _sending,
            onPressed: _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep(ThemeData theme) {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification code',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: SkillNovaSpacing.xs),
        TextField(
          controller: _otpController,
          focusNode: _otpFocus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
          decoration: const InputDecoration(hintText: '••••••'),
          onChanged: (value) {
            if (_error != null) setState(() => _error = null);
            if (value.length == 6) _verify();
          },
        ),
        const SizedBox(height: SkillNovaSpacing.xl),
        PrimaryButton(
          label: 'Verify',
          fullWidth: true,
          loading: _verifying,
          onPressed: _verify,
        ),
        const SizedBox(height: SkillNovaSpacing.sm),
        Row(
          children: [
            TextButton(
              onPressed: _verifying ? null : _changeNumber,
              child: const Text('Change number'),
            ),
            const Spacer(),
            TextButton(
              onPressed: _resendIn > 0 || _sending
                  ? null
                  : () => _sendCode(resend: true),
              child: Text(
                _resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend code',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
