import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:skill_link/screens/auth_screens/auth_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE6EBF2);

  String _selectedRole = 'customer';
  bool _isNavigating = false;

  final List<RoleOption> _roles = const [
    RoleOption(
      value: 'customer',
      eyebrow: 'HIRE WITH CONFIDENCE',
      title: 'I need a skilled worker',
      subtitle:
          'Post your job, compare nearby professionals and hire the right person for your work.',
      icon: Icons.person_search_rounded,
      badgeIcon: Icons.location_on_rounded,
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF06B6D4),
      benefits: [
        'Post jobs in minutes',
        'Compare ratings and offers',
        'Chat before hiring',
      ],
    ),
    RoleOption(
      value: 'worker',
      eyebrow: 'GROW YOUR INCOME',
      title: 'I am a skilled worker',
      subtitle:
          'Discover nearby job opportunities, connect with customers and build your professional reputation.',
      icon: Icons.handyman_rounded,
      badgeIcon: Icons.trending_up_rounded,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF059669),
      benefits: [
        'Find local job leads',
        'Showcase your skills',
        'Build reviews and income',
      ],
    ),
  ];

  RoleOption get _activeRole =>
      _roles.firstWhere((role) => role.value == _selectedRole);

  Future<void> _continue() async {
    if (_isNavigating) return;

    setState(() => _isNavigating = true);

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: AuthScreen(role: _selectedRole),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRole = _activeRole;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: _ambientCircle(
              size: 310,
              color: activeRole.primaryColor.withOpacity(0.10),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -130,
            child: _ambientCircle(
              size: 330,
              color: activeRole.secondaryColor.withOpacity(0.08),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(activeRole),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: size.height - 180,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heroSection(activeRole),
                          const SizedBox(height: 24),
                          _roleOptions(),
                          const SizedBox(height: 22),
                          _trustStrip(activeRole),
                        ],
                      ),
                    ),
                  ),
                ),
                _bottomAction(activeRole),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(RoleOption role) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  role.primaryColor,
                  role.secondaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: role.primaryColor.withOpacity(0.22),
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
          const SizedBox(width: 11),
          const Text(
            'SkillNova',
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
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF16A34A),
                  size: 14,
                ),
                SizedBox(width: 5),
                Text(
                  'Trusted',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroSection(RoleOption role) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            role.primaryColor,
            role.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: role.primaryColor.withOpacity(0.26),
            blurRadius: 28,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -62,
            right: -52,
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
            bottom: -72,
            left: -45,
            child: Container(
              height: 160,
              width: 160,
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
                    child: const Icon(
                      Icons.people_alt_rounded,
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
                    child: const Text(
                      'STEP 1 OF 2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 23),
              const Text(
                'Choose how you want\nto use SkillNova',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select the role that best matches what you want to do. You can complete your profile in the next step.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontSize: 13.2,
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

  Widget _roleOptions() {
    return Column(
      children: _roles
          .map(
            (role) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _roleCard(role),
            ),
          )
          .toList(),
    );
  }

  Widget _roleCard(RoleOption role) {
    final isSelected = _selectedRole == role.value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? role.primaryColor
              : _border,
          width: isSelected ? 1.7 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? role.primaryColor.withOpacity(0.14)
                : const Color(0x080F172A),
            blurRadius: isSelected ? 24 : 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            setState(() => _selectedRole = role.value);
          },
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            role.primaryColor,
                            role.secondaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color:
                                role.primaryColor.withOpacity(0.22),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        role.icon,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role.eyebrow,
                            style: TextStyle(
                              color: role.primaryColor,
                              fontSize: 9.8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            role.title,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 16.5,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            role.subtitle,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11.8,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? role.primaryColor
                            : const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? role.primaryColor
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 17,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? role.primaryColor.withOpacity(0.055)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: role.benefits
                        .map(
                          (benefit) => Padding(
                            padding: EdgeInsets.only(
                              bottom: benefit == role.benefits.last
                                  ? 0
                                  : 9,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 24,
                                  width: 24,
                                  decoration: BoxDecoration(
                                    color: role.primaryColor
                                        .withOpacity(0.10),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    color: role.primaryColor,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    benefit,
                                    style: const TextStyle(
                                      color: _textPrimary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trustStrip(RoleOption role) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: role.primaryColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: role.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Built for customers and professionals',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'A trusted marketplace designed for safer local work connections.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.8,
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

  Widget _bottomAction(RoleOption role) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      decoration: BoxDecoration(
        color: _background.withOpacity(0.96),
        border: const Border(
          top: BorderSide(color: Color(0xFFE9EEF5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _isNavigating ? null : _continue,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: role.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      role.primaryColor.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      role.value == 'customer'
                          ? 'Continue as Customer'
                          : 'Continue as Worker',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You can update your profile information later.',
              style: TextStyle(
                color: _textSecondary.withOpacity(0.92),
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
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

class RoleOption {
  final String value;
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData badgeIcon;
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> benefits;

  const RoleOption({
    required this.value,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeIcon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.benefits,
  });
}
