import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'phone_verification_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String role;

  const EmailVerificationScreen({super.key, required this.role});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _verificationTimer;
  Timer? _cooldownTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _checking = false;
  bool _sending = false;
  bool _navigating = false;
  int _cooldown = 0;

  Color get _primary => widget.role == 'worker'
      ? const Color(0xFF10B981)
      : const Color(0xFF2563EB);

  Color get _primaryDark => widget.role == 'worker'
      ? const Color(0xFF047857)
      : const Color(0xFF1D4ED8);

  Color get _secondary => widget.role == 'worker'
      ? const Color(0xFF14B8A6)
      : const Color(0xFF6366F1);

  bool get _isWorker => widget.role == 'worker';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _showMessage(
        'Verification link has been sent. Please check your inbox or spam folder.',
      );
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _verificationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _check(showMessage: false),
    );
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _cooldownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _check({required bool showMessage}) async {
    if (_checking || _navigating) return;

    _checking = true;
    if (mounted) setState(() {});

    try {
      await _auth.currentUser?.reload();

      final user = _auth.currentUser;

      if (user == null) {
        if (showMessage && mounted) {
          _showMessage(
            'Your session has expired. Please sign in again to continue.',
            isError: true,
          );
        }
        return;
      }

      if (user.emailVerified) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted || _navigating) return;

        _navigating = true;
        _verificationTimer?.cancel();

        await _showVerificationSuccess();

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 420),
            pageBuilder: (_, animation, secondaryAnimation) {
              return PhoneVerificationScreen(role: widget.role);
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );

                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
          ),
        );
      } else if (showMessage && mounted) {
        _showMessage(
          'Your email has not been verified yet. Please check your inbox or spam folder and open the verification link.',
          isError: true,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (showMessage && mounted) {
        _showMessage(
          error.message ??
              "We couldn't verify your email status. Please try again.",
          isError: true,
        );
      }
    } catch (error) {
      if (showMessage && mounted) {
        _showMessage(
          'An error occurred while checking your email verification.',
          isError: true,
        );
      }
      debugPrint('Email verification check error: $error');
    } finally {
      _checking = false;
      if (mounted && !_navigating) setState(() {});
    }
  }

  Future<void> _resend() async {
    if (_sending || _cooldown > 0) return;

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Your session has expired. Please log in again.',
        isError: true,
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await user.sendEmailVerification();

      if (!mounted) return;

      setState(() => _cooldown = 60);

      _startCooldown();

      _showMessage(
        'Verification link has been sent again. Please check your inbox or spam folder.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.code == 'too-many-requests'
            ? 'Too many requests have been made. Please wait a moment and try again.'
            : error.message ?? 'Verification email could not be sent.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'An error occurred while sending the verification email.',
        isError: true,
      );
      debugPrint('Resend email verification error: $error');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _signOut() async {
    final confirmed = await _showSignOutConfirmation();

    if (!confirmed || !mounted) return;

    try {
      await _auth.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _showMessage(
        error.message ?? 'Sign out could not be completed.',
        isError: true,
      );
    }
  }

  Future<bool> _showSignOutConfirmation() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 34,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _danger.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: _danger,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Use another account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You will be signed out from this account and returned to the authentication screen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: const Text(
                          'Stay Here',
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: _danger,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _showVerificationSuccess() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future<void>.delayed(const Duration(milliseconds: 1100), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_rounded,
                    color: _success,
                    size: 47,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Email verified successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Moving to phone verification...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: isError ? _danger : _success,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: (isError ? _danger : _success).withOpacity(0.26),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email?.trim() ?? '';

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -140,
            right: -105,
            child: _ambientCircle(size: 300, color: _primary.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -160,
            left: -125,
            child: _ambientCircle(
              size: 330,
              color: _secondary.withOpacity(0.07),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 18),
                      _buildHero(),
                      const SizedBox(height: 18),
                      _buildEmailCard(email),
                      const SizedBox(height: 18),
                      _buildInstructionsCard(),
                      const SizedBox(height: 18),
                      _buildLiveStatusCard(),
                      const SizedBox(height: 18),
                      _buildPrimaryActions(),
                      const SizedBox(height: 18),
                      _buildSecurityCard(),
                      const SizedBox(height: 16),
                      _buildAccountAction(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            _isWorker ? Icons.handyman_rounded : Icons.person_outline_rounded,
            color: _primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Email Verification',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _isWorker
                    ? 'Worker account security'
                    : 'Customer account security',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'STEP 1',
            style: TextStyle(
              color: _primary,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, _secondary],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -75,
            right: -50,
            child: Container(
              width: 175,
              height: 175,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -95,
            left: -65,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACCOUNT PROTECTION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.3,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.75,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Verify your email address',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Confirm your email to protect your account and continue registration.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: 11.5,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: 0.25,
                        backgroundColor: Colors.white.withOpacity(0.16),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'EMAIL PROTECTION IN PROGRESS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.76),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.22),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    color: Colors.white,
                    size: 43,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmailCard(String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.alternate_email_rounded,
                  color: _primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification link sent to',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 9.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your registered email',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: _warning.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'AWAITING',
                  style: TextStyle(
                    color: _warning,
                    fontSize: 7.8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Icon(Icons.email_outlined, color: _primary, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    email.isEmpty ? 'Email not available' : email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.lock_outline_rounded,
                  color: _textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: _warning, size: 21),
              SizedBox(width: 8),
              Text(
                'Complete these steps',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _instructionRow(
            number: 1,
            icon: Icons.inbox_outlined,
            title: 'Open your inbox',
            subtitle: 'Find the email sent by SkillNova.',
          ),
          _instructionRow(
            number: 2,
            icon: Icons.touch_app_outlined,
            title: 'Tap the verification link',
            subtitle: 'The link will confirm your email securely.',
          ),
          _instructionRow(
            number: 3,
            icon: Icons.keyboard_return_rounded,
            title: 'Return to SkillNova',
            subtitle: 'This screen checks verification automatically.',
          ),
          _instructionRow(
            number: 4,
            icon: Icons.folder_outlined,
            title: 'Check Spam or Promotions',
            subtitle: 'The email may appear in another folder.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _instructionRow({
    required int number,
    required IconData icon,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: _primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, color: _textSecondary, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 9.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _primary,
                  backgroundColor: _primary.withOpacity(0.10),
                ),
                Icon(Icons.sync_rounded, color: _primary, size: 18),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _checking
                      ? 'Checking verification status...'
                      : 'Waiting for email verification',
                  style: TextStyle(
                    color: _primaryDark,
                    fontSize: 11.7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We automatically detect when your email is verified.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 9.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'LIVE',
              style: TextStyle(
                color: _primary,
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            onPressed: _checking ? null : () => _check(showMessage: true),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _primary.withOpacity(0.42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
              elevation: 0,
            ),
            icon: _checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_outlined, size: 20),
            label: Text(
              _checking
                  ? 'Checking Verification...'
                  : 'I Have Verified My Email',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: (_sending || _cooldown > 0) ? null : _resend,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: BorderSide(
                color: _cooldown > 0 ? _border : _primary.withOpacity(0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: _sending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  )
                : Icon(
                    _cooldown > 0 ? Icons.timer_outlined : Icons.send_outlined,
                    size: 19,
                  ),
            label: Text(
              _sending
                  ? 'Sending Email...'
                  : _cooldown > 0
                  ? 'Resend in $_cooldown seconds'
                  : 'Resend Verification Email',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primary.withOpacity(0.10),
            _secondary.withOpacity(0.06),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primary.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryDark, _primary, _secondary],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.enhanced_encryption_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your account stays protected',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This private verification link confirms that the email belongs to you. SkillNova never asks for your email password or verification code.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.2,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _protectionChip(Icons.lock_outline_rounded, 'Private link'),
                    _protectionChip(
                      Icons.visibility_off_outlined,
                      'Password safe',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _protectionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: _primaryDark,
              fontSize: 8.7,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountAction() {
    return Column(
      children: [
        TextButton.icon(
          onPressed: _signOut,
          style: TextButton.styleFrom(
            foregroundColor: _danger,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          ),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'Use Another Account',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Keep this screen open while we confirm your email.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 9.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _ambientCircle({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
