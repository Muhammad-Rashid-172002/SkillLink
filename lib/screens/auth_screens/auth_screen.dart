import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _info = Color(0xFF2563EB);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  late final AnimationController _animationController;
  late final Animation<double> _floatingAnimation;

  bool _isLogin = false;
  bool _hidePassword = true;
  bool _isLoading = false;
  bool _acceptTerms = false;
  bool _googleInitialized = false;

  bool get _isCustomer => widget.role.toLowerCase() == 'customer';
  bool get _isWorker => !_isCustomer;
  String get _role => _isCustomer ? 'customer' : 'worker';

  Color get _primary =>
      _isCustomer ? const Color(0xFF2563EB) : const Color(0xFF10B981);

  Color get _primaryDark =>
      _isCustomer ? const Color(0xFF1D4ED8) : const Color(0xFF047857);

  Color get _secondary =>
      _isCustomer ? const Color(0xFF06B6D4) : const Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeGoogleSignIn();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    } catch (error) {
      debugPrint('Google Sign-In initialization error: $error');
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();

    if (_isLoading) return;

    if (!_isLogin && !_acceptTerms) {
      _message(
        'Please accept the Terms of Service and Privacy Policy first.',
        error: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (!_googleInitialized) {
        await _initializeGoogleSignIn();
      }

      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(code: 'google-token-missing');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }

      final reference = _firestore.collection('users').doc(user.uid);
      final snapshot = await reference.get();

      if (!snapshot.exists) {
        await reference.set({
          'uid': user.uid,
          'name':
              (user.displayName ?? googleUser.displayName ?? 'SkillNova User')
                  .trim(),
          'email': user.email ?? googleUser.email,
          'photoUrl': user.photoURL ?? googleUser.photoUrl,
          'role': _role,
          'authProvider': 'google',
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'phoneVerified': user.phoneNumber != null,
          'phoneNumber': user.phoneNumber,
          'profileCompleted': false,
          'identityVerificationStatus': _role == 'worker'
              ? 'not_submitted'
              : 'not_required',
          'backgroundVerificationStatus': _role == 'worker'
              ? 'not_submitted'
              : 'not_required',
          'verificationLevel': _role == 'worker' ? 'unverified' : 'basic',
          'canAcceptJobs': false,
          'accountStatus': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snapshot.data() ?? <String, dynamic>{};
        final savedRole = data['role']?.toString().toLowerCase();

        if (savedRole != 'customer' && savedRole != 'worker') {
          await _auth.signOut();
          await _googleSignIn.signOut();
          throw FirebaseException(
            plugin: 'cloud_firestore',
            message: 'Account role is invalid.',
          );
        }

        if (savedRole != _role) {
          await _auth.signOut();
          await _googleSignIn.signOut();
          throw FirebaseException(
            plugin: 'cloud_firestore',
            message:
                'This Google account is registered as a $savedRole. Please select the correct role.',
          );
        }

        if (data['accountStatus'] == 'suspended' ||
            data['accountStatus'] == 'blocked') {
          await _auth.signOut();
          await _googleSignIn.signOut();
          throw FirebaseException(
            plugin: 'cloud_firestore',
            message: 'This account is restricted. Contact support.',
          );
        }

        await reference.set({
          'name': user.displayName ?? data['name'],
          'email': user.email ?? data['email'],
          'photoUrl': user.photoURL ?? data['photoUrl'],
          'authProvider': 'google',
          'emailVerified': true,
          'emailVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await saveFcmToken();

      if (!mounted) return;
      await _routeAuthenticatedUser(user.uid);
    } on GoogleSignInException catch (error) {
      debugPrint('Google Sign-In exception: $error');
      _message(
        'Google Sign-In was cancelled or could not be completed.',
        error: true,
      );
    } on FirebaseAuthException catch (error) {
      _message(_authMessage(error.code), error: true);
    } on FirebaseException catch (error) {
      _message(error.message ?? 'Google Sign-In failed.', error: true);
    } catch (error) {
      debugPrint('Google Sign-In error: $error');
      _message('Google Sign-In failed. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _routeAuthenticatedUser(String uid) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Profile record was not found.',
      );
    }

    final data = snapshot.data() ?? <String, dynamic>{};
    final savedRole = data['role']?.toString().toLowerCase();

    if (savedRole != 'customer' && savedRole != 'worker') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Account role is invalid.',
      );
    }

    if (!user.emailVerified) {
      _replace(EmailVerificationScreen(role: savedRole!));
      return;
    }

    if (data['phoneVerified'] != true || user.phoneNumber == null) {
      _replace(PhoneVerificationScreen(role: savedRole!));
      return;
    }

    if (data['profileCompleted'] != true) {
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
      _replace(
        identity == 'approved'
            ? const WorkerHomeScreen()
            : const WorkerVerificationCenterScreen(),
      );
    } else {
      _replace(const CustomerHomeScreen());
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_isLogin && !_acceptTerms) {
      _message(
        'Please accept the Terms of Service and Privacy Policy.',
        error: true,
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
      _message(_authMessage(error.code), error: true);
    } on FirebaseException catch (error) {
      _message(
        error.message ?? 'Something went wrong. Please try again.',
        error: true,
      );
    } catch (error) {
      _message(
        'Unable to complete your request. Please try again.',
        error: true,
      );
      debugPrint('Authentication submit error: $error');
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
      throw FirebaseAuthException(code: 'user-creation-failed');
    }

    final name = _nameController.text.trim();

    await user.updateDisplayName(name);

    // Force-refresh the freshly-created Firebase ID token so callable
    // authentication is available immediately after sign-up.
    await user.getIdToken(true);

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': user.email,
      'role': _role,
      'emailVerified': false,
      'phoneVerified': false,
      'phoneNumber': null,
      'profileCompleted': false,
      'identityVerificationStatus': _role == 'worker'
          ? 'not_submitted'
          : 'not_required',
      'backgroundVerificationStatus': _role == 'worker'
          ? 'not_submitted'
          : 'not_required',
      'verificationLevel': _role == 'worker' ? 'unverified' : 'basic',
      'canAcceptJobs': false,
      'accountStatus': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await saveFcmToken();

    try {
      await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('sendCustomVerificationEmail').call(<String, dynamic>{
        'uid': user.uid,
        'email': (user.email ?? _emailController.text.trim())
            .trim()
            .toLowerCase(),
      });
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'Custom verification email error: '
        '${error.code} - ${error.message}',
      );

      if (error.code != 'already-exists') {
        _message(
          error.message ??
              'Account created, but verification email could not be sent. '
                  'Please use resend on the verification screen.',
          error: true,
        );
      }
    } catch (error) {
      debugPrint('Custom verification email error: $error');
      _message(
        'Account created, but verification email could not be sent. '
        'Please use resend on the verification screen.',
        error: true,
      );
    }

    if (!mounted) return;

    _replace(EmailVerificationScreen(role: _role));
  }

  Future<void> _login() async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

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
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    if (!_validEmail(email)) {
      _message('Enter a valid email address first.', error: true);
      _emailFocus.requestFocus();
      return;
    }

    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('sendCustomPasswordResetEmail')
          .call(<String, dynamic>{'email': email});

      if (!mounted) return;

      await _showPasswordResetDialog(email);
    } on FirebaseFunctionsException catch (error) {
      _message(
        error.message ??
            'Password reset email could not be sent right now. '
                'Please try again.',
        error: true,
      );
    } on FirebaseAuthException catch (error) {
      _message(_authMessage(error.code), error: true);
    } catch (error) {
      debugPrint('Password reset callable error: $error');
      _message(
        'Password reset email could not be sent right now. '
        'Please try again.',
        error: true,
      );
    }
  }

  Future<void> _showPasswordResetDialog(String email) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    color: _primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Reset email sent',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Password reset instructions have been sent to\n$email',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text(
                      'Got It',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _replace(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 430),
        pageBuilder: (_, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.07, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _message(String text, {bool error = false}) {
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
              color: error ? _danger : _success,
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                BoxShadow(
                  color: (error ? _danger : _success).withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  error
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
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using another sign-in method.';
      case 'google-token-missing':
        return 'Google did not return a valid sign-in token.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  bool _validEmail(String value) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value);
  }

  void _changeMode(bool loginMode) {
    if (_isLoading || _isLogin == loginMode) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLogin = loginMode;
      _hidePassword = true;
      _acceptTerms = false;
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final isCompact = screen.height < 760 || screen.width < 360;
    final horizontalPadding = screen.width >= 700
        ? 32.0
        : (isCompact ? 14.0 : 20.0);

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            right: -115,
            child: _ambientCircle(size: 320, color: _primary.withOpacity(0.10)),
          ),
          Positioned(
            bottom: -165,
            left: -130,
            child: _ambientCircle(
              size: 350,
              color: _secondary.withOpacity(0.07),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  isCompact ? 10 : 16,
                  horizontalPadding,
                  isCompact ? 18 : 30,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      SizedBox(height: isCompact ? 10 : 18),
                      _buildHero(),
                      SizedBox(height: isCompact ? 12 : 18),
                      _buildAuthCard(),
                      if (!isCompact) ...[
                        const SizedBox(height: 18),
                        _buildTrustCard(),
                      ],
                      SizedBox(height: isCompact ? 10 : 14),
                      _buildBottomNote(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading) _buildBlockingLoader(),
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
            onTap: _isLoading ? null : () => Navigator.maybePop(context),
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
                'SkillNova',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _isWorker ? 'Worker access portal' : 'Customer access portal',
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
            _role.toUpperCase(),
            style: TextStyle(
              color: _primary,
              fontSize: 8.3,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.55,
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
            top: -78,
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
            bottom: -98,
            left: -68,
            child: Container(
              width: 195,
              height: 195,
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
                      child: Text(
                        _isWorker
                            ? 'TRUSTED WORKER NETWORK'
                            : 'RELIABLE LOCAL SERVICES',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Text(
                        _isLogin
                            ? 'Welcome back to SkillNova'
                            : 'Create your SkillNova account',
                        key: ValueKey(_isLogin),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Text(
                        _isLogin
                            ? 'Securely continue to your ${_role.toLowerCase()} dashboard.'
                            : _isWorker
                            ? 'Join verified professionals and start receiving service requests.'
                            : 'Find trusted workers and manage your service requests securely.',
                        key: ValueKey('${_isLogin}_${_role}'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.84),
                          fontSize: 11.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _heroFeature(Icons.verified_user_outlined, 'Secure'),
                        _heroFeature(Icons.flash_on_rounded, 'Fast'),
                        _heroFeature(Icons.support_agent_rounded, 'Trusted'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _floatingAnimation.value),
                    child: child,
                  );
                },
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
                    _isWorker
                        ? Icons.handyman_rounded
                        : Icons.person_search_rounded,
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

  Widget _heroFeature(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeSelector(),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Column(
                key: ValueKey(_isLogin),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLogin ? 'Sign in to continue' : 'Create your account',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isLogin
                        ? 'Enter your account credentials below.'
                        : 'Complete the details below to get started.',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 19),
                  if (!_isLogin) ...[
                    _field(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _emailFocus.requestFocus(),
                      inputFormatters: [LengthLimitingTextInputFormatter(60)],
                      validator: (value) {
                        if ((value?.trim().length ?? 0) < 3) {
                          return 'Enter your full name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  _field(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    label: 'Email Address',
                    hint: 'name@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: (value) {
                      if (!_validEmail(value?.trim() ?? '')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _hidePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    keyboardType: TextInputType.visiblePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: _isLogin
                        ? const [AutofillHints.password]
                        : const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if ((value?.length ?? 0) < 6) {
                        return 'Minimum 6 characters required.';
                      }
                      return null;
                    },
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration:
                        _decoration(
                          label: 'Password',
                          hint: 'Minimum 6 characters',
                          icon: Icons.lock_outline_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: _textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                  ),
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: _primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 13),
                    _buildTermsCard(),
                  ],
                  SizedBox(height: _isLogin ? 8 : 18),
                  _buildSubmitButton(),
                  const SizedBox(height: 16),
                  _buildSocialDivider(),
                  const SizedBox(height: 16),
                  _buildGoogleButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              text: 'Log In',
              loginMode: true,
              icon: Icons.login_rounded,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _modeButton(
              text: 'Sign Up',
              loginMode: false,
              icon: Icons.person_add_alt_1_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String text,
    required bool loginMode,
    required IconData icon,
  }) {
    final active = _isLogin == loginMode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : () => _changeMode(loginMode),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 48,
          decoration: BoxDecoration(
            color: active ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x100F172A),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: active ? _primary : _textSecondary, size: 18),
              const SizedBox(width: 7),
              Text(
                text,
                style: TextStyle(
                  color: active ? _primary : _textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      textCapitalization: keyboardType == TextInputType.emailAddress
          ? TextCapitalization.none
          : TextCapitalization.words,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: _decoration(label: label, hint: hint, icon: icon),
    );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary, size: 20),
      labelStyle: const TextStyle(
        color: _textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      errorStyle: const TextStyle(
        color: _danger,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: _danger, width: 1.6),
      ),
    );
  }

  Widget _buildTermsCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading
            ? null
            : () => setState(() => _acceptTerms = !_acceptTerms),
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _acceptTerms
                ? _primary.withOpacity(0.07)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: _acceptTerms ? _primary.withOpacity(0.30) : _border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 23,
                height: 23,
                decoration: BoxDecoration(
                  color: _acceptTerms ? _primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _acceptTerms ? _primary : _border,
                    width: 1.4,
                  ),
                ),
                child: _acceptTerms
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10.2,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          disabledBackgroundColor: _primary.withOpacity(0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
          elevation: 0,
        ),
        icon: Icon(
          _isLogin ? Icons.login_rounded : Icons.arrow_forward_rounded,
          size: 20,
        ),
        label: Text(
          _isLogin ? 'Log In Securely' : 'Create Secure Account',
          style: const TextStyle(fontSize: 13.2, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildSocialDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: _border, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 8.8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.75,
            ),
          ),
        ),
        Expanded(child: Divider(color: _border, height: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          backgroundColor: _surface,
          side: const BorderSide(color: _border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Text(
              _isLogin ? 'Continue with Google' : 'Sign up with Google',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: _info, size: 23),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Secure account protection',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _securityRow(
            Icons.mark_email_read_outlined,
            'Email ownership verification',
          ),
          _securityRow(
            Icons.phone_android_rounded,
            'Secure phone OTP verification',
          ),
        ],
      ),
    );
  }

  Widget _securityRow(IconData icon, String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Icon(icon, color: _info, size: 16),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1E40AF),
                fontSize: 9.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: _success, size: 16),
        ],
      ),
    );
  }

  Widget _buildBottomNote() {
    return Text(
      _isLogin
          ? 'Your account progress will continue from the last completed verification step.'
          : 'Email and phone verification are required before profile setup.',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _textSecondary,
        fontSize: 9.5,
        height: 1.45,
        fontWeight: FontWeight.w600,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 4, color: _primary),
              const SizedBox(height: 18),
              Text(
                _isLogin ? 'Signing you in...' : 'Creating your account...',
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _isLogin
                    ? 'Please wait while SkillNova securely loads your account.'
                    : 'Please wait while SkillNova creates your secure profile.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
