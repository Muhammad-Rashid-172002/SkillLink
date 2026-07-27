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

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _auth = FirebaseAuth.instance;
  Timer? _timer;
  bool _checking = false;
  bool _sending = false;
  int _cooldown = 0;

  Color get _primary => widget.role == 'worker'
      ? const Color(0xFF10B981)
      : const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check(false));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check(bool showMessage) async {
    if (_checking) return;
    _checking = true;
    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user?.emailVerified == true) {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PhoneVerificationScreen(role: widget.role),
          ),
        );
      } else if (showMessage && mounted) {
        _message('Email is not verified yet.', error: true);
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    if (_sending || _cooldown > 0) return;
    setState(() {
      _sending = true;
      _cooldown = 60;
    });
    try {
      await _auth.currentUser?.sendEmailVerification();
      _message('Verification email sent again.');
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _cooldown <= 1) {
          timer.cancel();
          if (mounted) setState(() => _cooldown = 0);
        } else {
          setState(() => _cooldown--);
        }
      });
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Unable to send email.', error: true);
      if (mounted) setState(() => _cooldown = 0);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _message(String text, {bool error = false}) {
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
    final email = _auth.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mark_email_unread_outlined,
                          size: 42, color: _primary),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Verify your email',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a verification link to\n$email',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _primary),
                        onPressed: _checking ? null : () => _check(true),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('I have verified my email'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _cooldown == 0 ? _resend : null,
                      child: Text(
                        _cooldown == 0
                            ? 'Resend verification email'
                            : 'Resend in $_cooldown seconds',
                      ),
                    ),
                    TextButton(
                      onPressed: _signOut,
                      child: const Text('Use another account'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Also check your Spam or Promotions folder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
