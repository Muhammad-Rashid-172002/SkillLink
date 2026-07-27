import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'email_verification_screen.dart';
import 'phone_verification_screen.dart';
import '../verification/worker_verification_center.dart';
import 'package:skill_link/screens/customer_screens/home_Screen/customer_home_screen.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_setup_screen.dart';
import 'package:skill_link/screens/worker_screens/home_screen/worker_dashbaord.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_setup.dart';
import 'package:skill_link/services/saveFcmToken.dart';

class AuthScreen extends StatefulWidget {
  final String role;

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLogin = false;
  bool _hidePassword = true;
  bool _isLoading = false;
  bool _acceptTerms = false;

  bool get _isCustomer => widget.role.toLowerCase() == 'customer';
  String get _role => _isCustomer ? 'customer' : 'worker';
  Color get _primary =>
      _isCustomer ? const Color(0xFF2563EB) : const Color(0xFF10B981);
  Color get _secondary =>
      _isCustomer ? const Color(0xFF06B6D4) : const Color(0xFF059669);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;

    if (!_isLogin && !_acceptTerms) {
      _message('Please accept the Terms and Privacy Policy.', error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _login();
      } else {
        await _signUp();
      }
    } on FirebaseAuthException catch (e) {
      _message(_authMessage(e.code), error: true);
    } on FirebaseException catch (e) {
      _message(e.message ?? 'Something went wrong.', error: true);
    } catch (e) {
      _message('Unable to complete your request. $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-creation-failed');
    }

    final name = _nameController.text.trim();
    await user.updateDisplayName(name);
    await user.sendEmailVerification();

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': user.email,
      'role': _role,
      'emailVerified': false,
      'phoneVerified': false,
      'phoneNumber': null,
      'profileCompleted': false,
      'identityVerificationStatus':
          _role == 'worker' ? 'not_submitted' : 'not_required',
      'backgroundVerificationStatus':
          _role == 'worker' ? 'not_submitted' : 'not_required',
      'verificationLevel': _role == 'worker' ? 'unverified' : 'basic',
      'canAcceptJobs': false,
      'accountStatus': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await saveFcmToken();
    if (!mounted) return;
    _replace(EmailVerificationScreen(role: _role));
  }

  Future<void> _login() async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    final user = credential.user;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found');

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists) {
      await _auth.signOut();
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Profile record was not found.',
      );
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final savedRole = data['role']?.toString().toLowerCase();
    if (savedRole != 'customer' && savedRole != 'worker') {
      await _auth.signOut();
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Account role is invalid.',
      );
    }

    if (data['accountStatus'] == 'suspended' ||
        data['accountStatus'] == 'blocked') {
      await _auth.signOut();
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'This account is restricted. Contact support.',
      );
    }

    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) return;

    await saveFcmToken();
    if (!mounted) return;

    if (!refreshed.emailVerified) {
      _replace(EmailVerificationScreen(role: savedRole!));
      return;
    }

    await _firestore.collection('users').doc(user.uid).set({
      'emailVerified': true,
      'emailVerifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (data['phoneVerified'] != true || refreshed.phoneNumber == null) {
      _replace(PhoneVerificationScreen(role: savedRole!));
      return;
    }

    final profileCompleted = data['profileCompleted'] == true;
    if (!profileCompleted) {
      _replace(
        savedRole == 'worker'
            ? const WorkerProfileSetupScreen()
            : const CustomerProfileSetupScreen(),
      );
      return;
    }

    if (savedRole == 'worker') {
      final identity =
          data['identityVerificationStatus']?.toString() ?? 'not_submitted';
      if (identity != 'approved') {
        _replace(const WorkerVerificationCenterScreen());
      } else {
        _replace(const WorkerHomeScreen());
      }
    } else {
      _replace(const CustomerHomeScreen());
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!_validEmail(email)) {
      _message('Enter a valid email first.', error: true);
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _message('Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      _message(_authMessage(e.code), error: true);
    }
  }

  void _replace(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          content: Text(text),
        ),
      );
  }

  String _authMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must contain at least 6 characters.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  bool _validEmail(String value) => RegExp(
        r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
      ).hasMatch(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_primary, _secondary]),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SkillNova',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Welcome back to your secure ${_role.toUpperCase()} account.'
                              : 'Create a secure ${_role.toUpperCase()} account.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.84),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: _border),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _modeButton('Log in', true)),
                              const SizedBox(width: 8),
                              Expanded(child: _modeButton('Sign up', false)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (!_isLogin) ...[
                            _field(
                              controller: _nameController,
                              label: 'Full name',
                              icon: Icons.person_outline,
                              validator: (v) => (v?.trim().length ?? 0) < 3
                                  ? 'Enter your full name.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                          ],
                          _field(
                            controller: _emailController,
                            label: 'Email address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => !_validEmail(v?.trim() ?? '')
                                ? 'Enter a valid email.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _hidePassword,
                            validator: (v) => (v?.length ?? 0) < 6
                                ? 'Minimum 6 characters required.'
                                : null,
                            decoration: _decoration(
                              'Password',
                              Icons.lock_outline,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_isLogin)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : _forgotPassword,
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(color: _primary),
                                ),
                              ),
                            )
                          else
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _acceptTerms,
                              activeColor: _primary,
                              onChanged: (v) =>
                                  setState(() => _acceptTerms = v ?? false),
                              title: const Text(
                                'I agree to the Terms of Service and Privacy Policy.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: _primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isLogin
                                          ? 'Log in securely'
                                          : 'Create account',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your email and phone number must be verified before profile setup.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String text, bool loginMode) {
    final active = _isLogin == loginMode;
    return OutlinedButton(
      onPressed: _isLoading
          ? null
          : () => setState(() {
                _isLogin = loginMode;
                _formKey.currentState?.reset();
              }),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? _primary.withOpacity(.09) : Colors.white,
        side: BorderSide(color: active ? _primary : _border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? _primary : _textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _decoration(label, icon),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _primary, width: 1.6),
      ),
    );
  }
}
