import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_setup_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_setup.dart';
import 'package:skill_link/services/saveFcmToken.dart';

class AuthScreen extends StatefulWidget {
  final String role; // customer OR worker

  const AuthScreen({
    super.key,
    required this.role,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE4EAF2);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLogin = false;
  bool _hidePassword = true;
  bool _isLoading = false;
  bool _acceptTerms = false;

  bool get _isCustomer => widget.role.toLowerCase() == 'customer';

  Color get _primaryColor =>
      _isCustomer ? const Color(0xFF2563EB) : const Color(0xFF10B981);

  Color get _secondaryColor =>
      _isCustomer ? const Color(0xFF06B6D4) : const Color(0xFF059669);

  String get _roleTitle => _isCustomer ? 'Customer' : 'Worker';

  IconData get _roleIcon =>
      _isCustomer ? Icons.person_search_rounded : Icons.handyman_rounded;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isLoading) return;

    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    if (!_isLogin && !_acceptTerms) {
      _showMessage(
        'Please accept the Terms of Service and Privacy Policy.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _login();
      } else {
        await _signUp();
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(
        _firebaseMessage(error.code),
        isError: true,
      );
    } on FirebaseException catch (error) {
      _showMessage(
        error.message ?? 'Something went wrong. Please try again.',
        isError: true,
      );
    } catch (_) {
      _showMessage(
        'Unable to complete your request. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUp() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-creation-failed',
        message: 'Account could not be created.',
      );
    }

    final cleanName = _nameController.text.trim();

    await user.updateDisplayName(cleanName);

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': cleanName,
      'email': _emailController.text.trim(),
      'role': widget.role.toLowerCase(),
      'profileCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await saveFcmToken();

    if (!mounted) return;

    _openProfileSetup(widget.role.toLowerCase());
  }

  Future<void> _login() async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Account not found.',
      );
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      await _auth.signOut();

      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Your profile record was not found. Please create an account.',
      );
    }

    final data = userDoc.data();
    final savedRole = data?['role']?.toString().trim().toLowerCase();

    if (savedRole != 'customer' && savedRole != 'worker') {
      await _auth.signOut();

      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Your account role is invalid. Please contact support.',
      );
    }

    if (!mounted) return;

    _openProfileSetup(savedRole!);
  }

  void _openProfileSetup(String role) {
    final Widget nextScreen = role == 'worker'
        ? const WorkerProfileSetupScreen()
        : const CustomerProfileSetupScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: nextScreen,
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      _showMessage(
        'Enter a valid email address first.',
        isError: true,
      );
      _emailFocus.requestFocus();
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      _showMessage(
        'Password reset link has been sent to your email.',
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(
        _firebaseMessage(error.code),
        isError: true,
      );
    }
  }

  void _switchMode(bool login) {
    if (_isLoading || _isLogin == login) return;

    setState(() {
      _isLogin = login;
      _hidePassword = true;
    });

    _formKey.currentState?.reset();
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  String _firebaseMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must contain at least 6 characters.';
      case 'user-not-found':
        return 'No account was found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _ambientCircle(
              size: 310,
              color: _primaryColor.withOpacity(0.11),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -130,
            child: _ambientCircle(
              size: 330,
              color: _secondaryColor.withOpacity(0.08),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - 72,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(),
                    const SizedBox(height: 18),
                    _heroSection(),
                    const SizedBox(height: 20),
                    _authCard(),
                    const SizedBox(height: 18),
                    _securityNote(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Material(
          color: _surface,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: _isLoading
                ? null
                : () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const RoleSelectionScreen(),
                      ),
                    );
                  },
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _textPrimary,
                size: 21,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.22),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.handyman_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'SkillLink',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.45,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.09),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _primaryColor.withOpacity(0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _roleIcon,
                color: _primaryColor,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                _roleTitle,
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _secondaryColor],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -68,
            right: -54,
            child: Container(
              height: 180,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -75,
            left: -45,
            child: Container(
              height: 165,
              width: 165,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                      ),
                    ),
                    child: Icon(
                      _roleIcon,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isLogin ? 'WELCOME BACK' : 'JOIN SKILLLINK',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  _isLogin
                      ? 'Welcome back to\nSkillLink'
                      : 'Create your\n$_roleTitle account',
                  key: ValueKey(_isLogin),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isCustomer
                    ? 'Find trusted professionals and manage your work requests with confidence.'
                    : 'Connect with nearby customers, find job opportunities and grow your reputation.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.83),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _authCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 25,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _modeSwitcher(),
            const SizedBox(height: 22),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              child: Column(
                children: [
                  if (!_isLogin) ...[
                    _inputField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      nextFocus: _emailFocus,
                      label: 'Full name',
                      hint: 'Enter your full name',
                      icon: Icons.person_outline_rounded,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        final text = value?.trim() ?? '';

                        if (_isLogin) return null;
                        if (text.isEmpty) return 'Full name is required.';
                        if (text.length < 3) {
                          return 'Enter at least 3 characters.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _inputField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    nextFocus: _passwordFocus,
                    label: 'Email address',
                    hint: 'you@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isEmpty) return 'Email address is required.';
                      if (!_isValidEmail(email)) {
                        return 'Enter a valid email address.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _passwordField(),
                  if (_isLogin) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 11.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    _termsCheckbox(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _primaryButton(),
            const SizedBox(height: 20),
            _divider(),
            const SizedBox(height: 18),
            _googleButton(),
            const SizedBox(height: 20),
            _bottomPrompt(),
          ],
        ),
      ),
    );
  }

  Widget _modeSwitcher() {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _modeItem(
            title: 'Log in',
            active: _isLogin,
            onTap: () => _switchMode(true),
          ),
          _modeItem(
            title: 'Sign up',
            active: !_isLogin,
            onTap: () => _switchMode(false),
          ),
        ],
      ),
    );
  }

  Widget _modeItem({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x100F172A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: active ? _primaryColor : _textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    FocusNode? nextFocus,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction:
              nextFocus == null ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: (_) {
            if (nextFocus != null) {
              nextFocus.requestFocus();
            } else {
              _submit();
            }
          },
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
          ),
        ),
      ],
    );
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Password'),
        TextFormField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: _hidePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            final password = value ?? '';

            if (password.isEmpty) return 'Password is required.';
            if (password.length < 6) {
              return 'Password must contain at least 6 characters.';
            }

            return null;
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _inputDecoration(
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _hidePassword = !_hidePassword);
              },
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: const Color(0xFF94A3B8),
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 3,
        bottom: 8,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF94A3B8),
        size: 21,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 17,
      ),
      errorStyle: const TextStyle(
        fontSize: 10.8,
        fontWeight: FontWeight.w700,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: _primaryColor,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _termsCheckbox() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isLoading
          ? null
          : () {
              setState(() => _acceptTerms = !_acceptTerms);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 22,
              width: 22,
              decoration: BoxDecoration(
                color: _acceptTerms
                    ? _primaryColor
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color:
                      _acceptTerms ? _primaryColor : const Color(0xFFCBD5E1),
                ),
              ),
              child: _acceptTerms
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 10.8,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primaryColor.withOpacity(0.62),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 21,
                  width: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey('button-text'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? 'Log in securely' : 'Create account',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(
                      _isLogin
                          ? Icons.login_rounded
                          : Icons.arrow_forward_rounded,
                      size: 19,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: _border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: _border)),
      ],
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: _isLoading
            ? null
            : () {
                _showMessage(
                  'Google Sign-In integration can be connected here.',
                );
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          backgroundColor: _surface,
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'G',
              style: TextStyle(
                color: Color(0xFF4285F4),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Continue with Google',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomPrompt() {
    return GestureDetector(
      onTap: _isLoading ? null : () => _switchMode(!_isLogin),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 11.8,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(
              text: _isLogin
                  ? 'Don’t have an account? '
                  : 'Already have an account? ',
            ),
            TextSpan(
              text: _isLogin ? 'Sign up' : 'Log in',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _securityNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 39,
            width: 39,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: _primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your account is protected',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 11.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Never share your password or verification code with anyone.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.4,
                    height: 1.35,
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

  Widget _ambientCircle({
    required double size,
    required Color color,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 50,
        sigmaY: 50,
      ),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
