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

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;
  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;

  Color get _primary => widget.role == 'worker'
      ? const Color(0xFF10B981)
      : const Color(0xFF2563EB);

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _normalizePakistanPhone(String raw) {
    var phone = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.startsWith('0092')) phone = '+92${phone.substring(4)}';
    if (phone.startsWith('92') && !phone.startsWith('+92')) phone = '+$phone';
    if (phone.startsWith('03')) phone = '+92${phone.substring(1)}';
    if (RegExp(r'^3\d{9}$').hasMatch(phone)) phone = '+92$phone';
    return RegExp(r'^\+923\d{9}$').hasMatch(phone) ? phone : null;
  }

  Future<void> _sendCode({bool resend = false}) async {
    final phone = _normalizePakistanPhone(_phoneController.text);
    if (phone == null) {
      _message('Enter a valid Pakistani mobile number.', error: true);
      return;
    }

    setState(() => _sending = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resend ? _resendToken : null,
      verificationCompleted: (credential) async {
        await _completeVerification(credential, phone);
      },
      verificationFailed: (e) {
        if (mounted) setState(() => _sending = false);
        _message(e.message ?? 'Phone verification failed.', error: true);
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSent = true;
          _sending = false;
        });
        _message('OTP sent to $phone');
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        if (mounted) setState(() => _sending = false);
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _verifyCode() async {
    final id = _verificationId;
    final code = _otpController.text.trim();
    final phone = _normalizePakistanPhone(_phoneController.text);
    if (id == null || phone == null || code.length != 6) {
      _message('Enter the 6-digit OTP.', error: true);
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: id,
      smsCode: code,
    );
    await _completeVerification(credential, phone);
  }

  Future<void> _completeVerification(
    PhoneAuthCredential credential,
    String phone,
  ) async {
    if (_verifying) return;
    setState(() => _verifying = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'user-not-found');

      try {
        await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') {
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => widget.role == 'worker'
              ? const WorkerProfileSetupScreen()
              : const CustomerProfileSetupScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _message(_firebaseMessage(e.code), error: true);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String _firebaseMessage(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'The OTP is incorrect.';
      case 'session-expired':
        return 'OTP expired. Request a new code.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Unable to verify phone number.';
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Phone verification'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.phone_android_rounded, size: 58, color: _primary),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify your mobile number',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use a number that belongs to you. We will send a one-time password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _phoneController,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                    ],
                    decoration: _decoration(
                      'Mobile number',
                      Icons.phone_outlined,
                      hint: '+92 300 1234567',
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _decoration(
                        '6-digit OTP',
                        Icons.password_rounded,
                      ).copyWith(counterText: ''),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _primary),
                      onPressed: (_sending || _verifying)
                          ? null
                          : (_codeSent ? _verifyCode : _sendCode),
                      child: (_sending || _verifying)
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_codeSent ? 'Verify OTP' : 'Send OTP'),
                    ),
                  ),
                  if (_codeSent)
                    TextButton(
                      onPressed: _sending ? null : () => _sendCode(resend: true),
                      child: const Text('Resend OTP'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primary, width: 1.6),
      ),
    );
  }
}
