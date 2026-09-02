import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/auth_screens/email_verification_screen.dart';
import 'package:skill_link/screens/auth_screens/phone_verification_screen.dart';
import 'package:skill_link/screens/customer_screens/navigation/customer_navigation_shell.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_setup_screen.dart';
import 'package:skill_link/screens/onboarding_screen/OnboardingScreen.dart';
import 'package:skill_link/screens/verification/worker_verification_center.dart';
import 'package:skill_link/screens/worker_screens/home_screen/worker_dashbaord.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_setup.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _navy = Color(0xFF0F172A);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _green = Color(0xFF10B981);

  late final AnimationController _introController;
  late final AnimationController _pulseController;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _pulseAnimation;

  bool _isCheckingUser = false;
  String _loadingText = 'Preparing your experience';

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(
        0.0,
        0.72,
        curve: Curves.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.72,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(
          0.25,
          1,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _pulseAnimation = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _introController.forward();
    _startSplashFlow();
  }

  Future<void> _startSplashFlow() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));

    if (!mounted) return;

    setState(() {
      _loadingText = 'Checking your account';
    });

    await _checkUser();
  }

  Future<void> _checkUser() async {
    if (_isCheckingUser) return;
    _isCheckingUser = true;

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (user == null) {
        _goTo(const OnboardingScreen());
        return;
      }

      await user.reload();
      final refreshedUser = auth.currentUser;

      if (refreshedUser == null) {
        _goTo(const OnboardingScreen());
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshedUser.uid)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        await auth.signOut();
        _goTo(const OnboardingScreen());
        return;
      }

      final data = doc.data() ?? <String, dynamic>{};
      final role = data['role']?.toString().trim().toLowerCase();
      final accountStatus =
          data['accountStatus']?.toString().trim().toLowerCase() ?? 'active';

      if (role != 'customer' && role != 'worker') {
        await auth.signOut();
        _goTo(const OnboardingScreen());
        return;
      }

      if (accountStatus == 'suspended' || accountStatus == 'blocked') {
        await auth.signOut();
        _goTo(const OnboardingScreen());
        return;
      }

      if (!refreshedUser.emailVerified) {
        _goTo(EmailVerificationScreen(role: role!));
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(refreshedUser.uid)
          .set({
        'emailVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final phoneVerified = data['phoneVerified'] == true;
      if (!phoneVerified || refreshedUser.phoneNumber == null) {
        _goTo(PhoneVerificationScreen(role: role!));
        return;
      }

      final profileCompleted = data['profileCompleted'] == true;
      if (!profileCompleted) {
        _goTo(
          role == 'worker'
              ? const WorkerProfileSetupScreen()
              : const CustomerProfileSetupScreen(),
        );
        return;
      }

      if (role == 'customer') {
        _goTo(const CustomerNavigationShell());
        return;
      }

      final identityStatus =
          data['identityVerificationStatus']?.toString() ?? 'not_submitted';

      if (identityStatus != 'approved') {
        _goTo(const WorkerVerificationCenterScreen());
        return;
      }

      _goTo(const WorkerHomeScreen());
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() => _loadingText = 'Unable to connect');
      await Future<void>.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to connect. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _goTo(const OnboardingScreen());
    } catch (_) {
      if (!mounted) return;
      _goTo(const OnboardingScreen());
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: screen,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF07111F),
                  _navy,
                  Color(0xFF183A7A),
                  Color(0xFF0D7C66),
                ],
                stops: [0, 0.35, 0.70, 1],
              ),
            ),
          ),

          Positioned(
            top: -size.width * 0.34,
            right: -size.width * 0.24,
            child: _blurCircle(
              size: size.width * 0.90,
              color: _blue.withOpacity(0.28),
            ),
          ),

          Positioned(
            bottom: -size.width * 0.38,
            left: -size.width * 0.26,
            child: _blurCircle(
              size: size.width * 0.92,
              color: _green.withOpacity(0.25),
            ),
          ),

          Positioned(
            top: size.height * 0.16,
            left: -70,
            child: Transform.rotate(
              angle: -0.38,
              child: Container(
                height: 170,
                width: 170,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(46),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 22,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const Spacer(),

                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: _logoCard(),
                      ),
                    ),

                    const SizedBox(height: 30),

                    SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          const Text(
                            'SkillNova',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Trusted skills. Reliable people.\nWork done with confidence.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 14.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    _loadingSection(),

                    const SizedBox(height: 22),

                    Text(
                      'Connecting customers with skilled professionals',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.52),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoCard() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 150,
          width: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.06),
          ),
        ),

        Container(
          height: 126,
          width: 126,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.24),
                Colors.white.withOpacity(0.10),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.28),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: _green.withOpacity(0.18),
                blurRadius: 42,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 14,
                sigmaY: 14,
              ),
              child: const Center(
                child: Icon(
                  Icons.handyman_rounded,
                  size: 63,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        Positioned(
          right: 7,
          bottom: 16,
          child: Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _green.withOpacity(0.35),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadingSection() {
    return Column(
      children: [
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Color(0x26FFFFFF),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            _loadingText,
            key: ValueKey(_loadingText),
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _blurCircle({
    required double size,
    required Color color,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 58,
        sigmaY: 58,
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
