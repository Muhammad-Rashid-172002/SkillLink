import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:skill_link/screens/customer_screens/profile/customer_profile_setup_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_setup.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String role;

  const PhoneVerificationScreen({super.key, required this.role});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _info = Color(0xFF2563EB);

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Timer? _resendTimer;

  String? _verificationId;
  String? _normalizedPhone;
  int? _resendToken;

  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;
  bool _navigating = false;
  int _resendSeconds = 0;

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _otpController.addListener(_handleOtpChange);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _pulseController.dispose();
    _phoneController.dispose();
    _otpController.removeListener(_handleOtpChange);
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _handleOtpChange() {
    if (mounted) setState(() {});

    if (_otpController.text.trim().length == 6 &&
        !_verifying &&
        _verificationId != null) {
      FocusScope.of(context).unfocus();
    }
  }

  String? _normalizePakistanPhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');

    if (phone.startsWith('0092')) {
      phone = '+92${phone.substring(4)}';
    }

    if (phone.startsWith('92') && !phone.startsWith('+92')) {
      phone = '+$phone';
    }

    if (phone.startsWith('03')) {
      phone = '+92${phone.substring(1)}';
    }

    if (RegExp(r'^3\d{9}$').hasMatch(phone)) {
      phone = '+92$phone';
    }

    return RegExp(r'^\+923\d{9}$').hasMatch(phone) ? phone : null;
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_sending || _verifying) return;

    final phone = _normalizePakistanPhone(_phoneController.text);

    if (phone == null) {
      _showMessage(
        'Please enter a valid mobile number.',
        isError: true,
      );
      _phoneFocusNode.requestFocus();
      return;
    }

    setState(() => _sending = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: resend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _completeVerification(credential, phone);
        },
        verificationFailed: (error) {
          if (mounted) {
            setState(() => _sending = false);
            _showMessage(_firebaseMessage(error.code), isError: true);
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _normalizedPhone = phone;
            _codeSent = true;
            _sending = false;
            _otpController.clear();
          });

          _startResendTimer();
          _showMessage('OTP has been sent to $phone.');

          Future<void>.delayed(const Duration(milliseconds: 350), () {
            if (mounted) _otpFocusNode.requestFocus();
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;

          if (mounted) {
            setState(() => _sending = false);
          }
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() => _sending = false);
      _showMessage(_firebaseMessage(error.code), isError: true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _sending = false);
      _showMessage(
        'An unexpected error occurred while sending the OTP.',
        isError: true,
      );
      debugPrint('Phone verification send error: $error');
    }
  }

  Future<void> _verifyCode() async {
    if (_verifying || _sending) return;

    final verificationId = _verificationId;
    final code = _otpController.text.trim();
    final phone =
        _normalizedPhone ?? _normalizePakistanPhone(_phoneController.text);

    if (verificationId == null || phone == null) {
      _showMessage('Please request an OTP first.', isError: true);
      return;
    }

    if (code.length != 6) {
      _showMessage('Please enter a 6-digit OTP.', isError: true);
      _otpFocusNode.requestFocus();
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );

    await _completeVerification(credential, phone);
  }

  Future<void> _completeVerification(
    PhoneAuthCredential credential,
    String phone,
  ) async {
    if (_verifying || _navigating) return;

    setState(() => _verifying = true);

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      try {
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'provider-already-linked') {
          await user.updatePhoneNumber(credential);
        } else {
          rethrow;
        }
      }

      await user.reload();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phoneNumber': phone,
        'phone': phone,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _navigating = true;
      _resendTimer?.cancel();

      await _showSuccessDialog(phone);

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 430),
          pageBuilder: (_, animation, secondaryAnimation) {
            return _isWorker
                ? const WorkerProfileSetupScreen()
                : const CustomerProfileSetupScreen();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _showMessage(_firebaseMessage(error.code), isError: true);

      if (error.code == 'invalid-verification-code') {
        _otpController.clear();
        _otpFocusNode.requestFocus();
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage('An error occurred while completing phone verification.', isError: true);
      debugPrint('Phone verification complete error: $error');
    } finally {
      if (mounted && !_navigating) {
        setState(() => _verifying = false);
      }
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();

    setState(() => _resendSeconds = 60);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _changeNumber() {
    if (_sending || _verifying) return;

    _resendTimer?.cancel();

    setState(() {
      _codeSent = false;
      _verificationId = null;
      _resendToken = null;
      _normalizedPhone = null;
      _resendSeconds = 0;
      _otpController.clear();
    });

    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _phoneFocusNode.requestFocus();
    });
  }

  String _firebaseMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Please enter a valid mobile number.';
      case 'invalid-verification-code':
        return 'Please check the OTP and try again.';
      case 'session-expired':
        return 'OTP has expired. Please request a new code.';
      case 'credential-already-in-use':
        return 'This phone number is linked to another account.';
      case 'too-many-requests':
        return 'Too many attempts have been made. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota has been exceeded. Please try again later.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      case 'user-not-found':
        return 'User session not found. Please log in again.';
      default:
        return 'Phone number could not be verified.';
    }
  }

  Future<void> _showSuccessDialog(String phone) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future<void>.delayed(const Duration(milliseconds: 1400), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Container(
            padding: const EdgeInsets.all(26),
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
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: _success.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    color: _success,
                    size: 47,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Phone verified successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  phone,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _success,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _isWorker
                      ? 'Moving to worker profile setup...'
                      : 'Moving to customer profile setup...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10.5,
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
                  color: (isError ? _danger : _success).withOpacity(0.25),
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
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -145,
            right: -105,
            child: _ambientCircle(size: 305, color: _primary.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -165,
            left: -125,
            child: _ambientCircle(
              size: 340,
              color: _secondary.withOpacity(0.07),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 18),
                      _buildHero(),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _codeSent ? _buildOtpCard() : _buildPhoneCard(),
                      ),
                      const SizedBox(height: 18),
                      _buildLiveStatusCard(),
                      const SizedBox(height: 18),
                      _buildPrimaryActions(),
                      const SizedBox(height: 18),
                      _buildSecurityCard(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_verifying) _buildBlockingLoader(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_sending || _verifying)
                ? null
                : () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phone Verification',
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
            'STEP 2',
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
            top: -80,
            right: -55,
            child: Container(
              width: 180,
              height: 180,
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
                        'SECURE MOBILE VERIFICATION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _codeSent
                          ? 'Enter your verification code'
                          : 'Verify your mobile number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _codeSent
                          ? 'We sent a one-time password to your registered number.'
                          : 'Use a number that belongs to you to secure your account.',
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
                        value: 0.50,
                        backgroundColor: Colors.white.withOpacity(0.16),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '2 OF 4 VERIFICATION STEPS',
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
                  child: Icon(
                    _codeSent ? Icons.sms_outlined : Icons.phone_iphone_rounded,
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

  Widget _buildPhoneCard() {
    return Container(
      key: const ValueKey('phone-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(25),
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
          const Text(
            'Mobile Number',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Pakistan mobile numbers only',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _border),
                ),
                child: const Row(
                  children: [
                    Text('🇵🇰', style: TextStyle(fontSize: 21)),
                    SizedBox(width: 7),
                    Text(
                      '+92',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                    LengthLimitingTextInputFormatter(18),
                  ],
                  onSubmitted: (_) => _sendCode(),
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '300 1234567',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: _primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 17,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(17),
                      borderSide: BorderSide(color: _primary, width: 1.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _primary, size: 18),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Example: 0300 1234567 or +92 300 1234567',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 9.6,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpCard() {
    final code = _otpController.text.trim();

    return Container(
      key: const ValueKey('otp-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(25),
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
                child: Icon(Icons.sms_outlined, color: _primary, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter 6-digit OTP',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _normalizedPhone ?? '',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _changeNumber,
                child: Text(
                  'Change',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _otpFocusNode.requestFocus(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    height: 1,
                    width: 1,
                    child: TextField(
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final filled = index < code.length;
                    final active = index == code.length && code.length < 6;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: filled
                            ? _primary.withOpacity(0.08)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: filled || active ? _primary : _border,
                          width: active ? 1.7 : 1.0,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: _primary.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        filled ? code[index] : '',
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'OTP automatically detect ho sakta hai. Warna SMS se code enter karein.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 9.6,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard() {
    final isWaiting = _codeSent && !_verifying;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: (isWaiting ? _warning : _primary).withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isWaiting ? _warning : _primary).withOpacity(0.18),
        ),
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
                  color: isWaiting ? _warning : _primary,
                  backgroundColor: (isWaiting ? _warning : _primary)
                      .withOpacity(0.10),
                ),
                Icon(
                  isWaiting ? Icons.sms_rounded : Icons.shield_outlined,
                  color: isWaiting ? _warning : _primary,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _codeSent
                      ? 'Waiting for OTP confirmation'
                      : 'Ready for secure SMS verification',
                  style: TextStyle(
                    color: isWaiting ? const Color(0xFF92400E) : _primaryDark,
                    fontSize: 11.7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _codeSent
                      ? 'Enter the code received on your mobile number.'
                      : 'Firebase will send a one-time secure verification code.',
                  style: const TextStyle(
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
              color: (isWaiting ? _warning : _primary).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _codeSent ? 'SMS SENT' : 'SECURE',
              style: TextStyle(
                color: isWaiting ? _warning : _primary,
                fontSize: 7.3,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.45,
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
            onPressed: (_sending || _verifying)
                ? null
                : (_codeSent ? _verifyCode : _sendCode),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _primary.withOpacity(0.42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
              elevation: 0,
            ),
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _codeSent
                        ? Icons.verified_user_outlined
                        : Icons.send_to_mobile_rounded,
                    size: 20,
                  ),
            label: Text(
              _sending
                  ? 'Sending OTP...'
                  : _codeSent
                  ? 'Verify OTP'
                  : 'Send OTP',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        if (_codeSent) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: (_sending || _verifying || _resendSeconds > 0)
                  ? null
                  : () => _sendCode(resend: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: BorderSide(
                  color: _resendSeconds > 0
                      ? _border
                      : _primary.withOpacity(0.35),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(
                _resendSeconds > 0
                    ? Icons.timer_outlined
                    : Icons.refresh_rounded,
                size: 19,
              ),
              label: Text(
                _resendSeconds > 0
                    ? 'Resend in 00:${_resendSeconds.toString().padLeft(2, '0')}'
                    : 'Resend OTP',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person_outlined, color: _info, size: 23),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protected by Firebase Authentication',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'OTP is used only to confirm ownership of your mobile number. Never share your verification code with anyone.',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 10,
                    height: 1.5,
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

  Widget _buildBlockingLoader() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.50),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 34),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 34,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 4, color: _success),
              SizedBox(height: 18),
              Text(
                'Verifying your phone...',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Please keep the app open while SkillNova securely confirms your mobile number.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
