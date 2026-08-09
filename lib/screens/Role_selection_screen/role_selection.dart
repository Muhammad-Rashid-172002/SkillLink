import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:skill_link/screens/auth_screens/auth_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  static const Color _background = Color(0xFFF4F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE4EAF2);

  String _selectedRole = 'customer';
  bool _isNavigating = false;

  final List<RoleOption> _roles = const [
    RoleOption(
      value: 'customer',
      label: 'CUSTOMER',
      title: 'Hire a professional',
      subtitle: 'Post a job and choose the right skilled worker nearby.',
      icon: Icons.person_search_rounded,
      accentIcon: Icons.location_on_rounded,
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF06B6D4),
      benefitOne: 'Post jobs quickly',
      benefitTwo: 'Compare trusted workers',
    ),
    RoleOption(
      value: 'worker',
      label: 'WORKER',
      title: 'Find local jobs',
      subtitle: 'Show your skills, connect with customers and grow income.',
      icon: Icons.handyman_rounded,
      accentIcon: Icons.trending_up_rounded,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF059669),
      benefitOne: 'Discover nearby work',
      benefitTwo: 'Build ratings and income',
    ),
  ];

  RoleOption get _activeRole =>
      _roles.firstWhere((role) => role.value == _selectedRole);

  Future<void> _continue() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: AuthScreen(role: _selectedRole),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRole = _activeRole;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          _backgroundDecor(activeRole),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final isTablet = width >= 600;
                final isCompact = height < 700 || width < 360;
                final horizontalPadding = isTablet ? 34.0 : 18.0;
                final maxContentWidth = isTablet ? 620.0 : 520.0;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        children: [
                          _topBar(
                            activeRole,
                            isCompact: isCompact,
                            isTablet: isTablet,
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, bodyConstraints) {
                                final designHeight = isTablet
                                    ? 680.0
                                    : isCompact
                                        ? 520.0
                                        : 610.0;

                                return Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: bodyConstraints.maxWidth,
                                      height: designHeight,
                                      child: _mainContent(
                                        activeRole,
                                        isCompact: isCompact,
                                        isTablet: isTablet,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _bottomAction(
                            activeRole,
                            isCompact: isCompact,
                            isTablet: isTablet,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundDecor(RoleOption role) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -120,
            child: _ambientCircle(
              size: 330,
              color: role.primaryColor.withOpacity(0.12),
            ),
          ),
          Positioned(
            bottom: -170,
            left: -130,
            child: _ambientCircle(
              size: 350,
              color: role.secondaryColor.withOpacity(0.09),
            ),
          ),
          Positioned(
            top: 180,
            left: -90,
            child: _ambientCircle(
              size: 180,
              color: role.secondaryColor.withOpacity(0.045),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(
    RoleOption role, {
    required bool isCompact,
    required bool isTablet,
  }) {
    final logoSize = isTablet ? 48.0 : isCompact ? 37.0 : 42.0;

    return Padding(
      padding: EdgeInsets.only(
        top: isCompact ? 8 : 14,
        bottom: isCompact ? 4 : 8,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            height: logoSize,
            width: logoSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [role.primaryColor, role.secondaryColor],
              ),
              borderRadius: BorderRadius.circular(isCompact ? 12 : 14),
              boxShadow: [
                BoxShadow(
                  color: role.primaryColor.withOpacity(0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.handyman_rounded,
              color: Colors.white,
              size: isTablet ? 25 : isCompact ? 19 : 22,
            ),
          ),
          SizedBox(width: isCompact ? 8 : 11),
          Text(
            'SkillNova',
            style: TextStyle(
              color: _textPrimary,
              fontSize: isTablet ? 24 : isCompact ? 18 : 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.55,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 10,
              vertical: isCompact ? 6 : 7,
            ),
            decoration: BoxDecoration(
              color: _surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: role.primaryColor,
                  size: isCompact ? 13 : 15,
                ),
                SizedBox(width: isCompact ? 4 : 5),
                Text(
                  'Trusted',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: isTablet ? 12 : isCompact ? 9.5 : 10.8,
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

  Widget _mainContent(
    RoleOption activeRole, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return Column(
      children: [
        _heroSection(
          activeRole,
          isCompact: isCompact,
          isTablet: isTablet,
        ),
        SizedBox(height: isTablet ? 24 : isCompact ? 12 : 18),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _roleCard(
                  _roles[0],
                  isCompact: isCompact,
                  isTablet: isTablet,
                ),
              ),
              SizedBox(height: isTablet ? 16 : isCompact ? 9 : 12),
              Expanded(
                child: _roleCard(
                  _roles[1],
                  isCompact: isCompact,
                  isTablet: isTablet,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isTablet ? 18 : isCompact ? 10 : 14),
        _trustStrip(
          activeRole,
          isCompact: isCompact,
          isTablet: isTablet,
        ),
      ],
    );
  }

  Widget _heroSection(
    RoleOption role, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : isCompact ? 15 : 20,
        isTablet ? 23 : isCompact ? 14 : 19,
        isTablet ? 24 : isCompact ? 15 : 20,
        isTablet ? 22 : isCompact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            role.primaryColor,
            Color.lerp(role.primaryColor, role.secondaryColor, 0.58)!,
            role.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(isCompact ? 22 : 28),
        boxShadow: [
          BoxShadow(
            color: role.primaryColor.withOpacity(0.25),
            blurRadius: isCompact ? 20 : 28,
            offset: Offset(0, isCompact ? 10 : 15),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -60,
            right: -45,
            child: Container(
              height: isCompact ? 135 : 175,
              width: isCompact ? 135 : 175,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -35,
            child: Container(
              height: isCompact ? 120 : 155,
              width: isCompact ? 120 : 155,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                height: isTablet ? 66 : isCompact ? 44 : 56,
                width: isTablet ? 66 : isCompact ? 44 : 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: Icon(
                  Icons.groups_2_rounded,
                  color: Colors.white,
                  size: isTablet ? 33 : isCompact ? 22 : 28,
                ),
              ),
              SizedBox(width: isCompact ? 11 : 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choose your role',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 29 : isCompact ? 20 : 25,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.65,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 7 : 9,
                            vertical: isCompact ? 5 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.16),
                            ),
                          ),
                          child: Text(
                            'STEP 1 OF 2',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 11 : isCompact ? 8 : 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 5 : 7),
                    Text(
                      'Select customer or worker to continue with the right experience.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.84),
                        fontSize: isTablet ? 14 : isCompact ? 10.2 : 12.3,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleCard(
    RoleOption role, {
    required bool isCompact,
    required bool isTablet,
  }) {
    final isSelected = _selectedRole == role.value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(isCompact ? 19 : 24),
        border: Border.all(
          color: isSelected ? role.primaryColor : _border,
          width: isSelected ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? role.primaryColor.withOpacity(0.15)
                : const Color(0x090F172A),
            blurRadius: isSelected ? 24 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isCompact ? 19 : 24),
        child: InkWell(
          borderRadius: BorderRadius.circular(isCompact ? 19 : 24),
          onTap: () => setState(() => _selectedRole = role.value),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 18 : isCompact ? 11 : 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  height: isTablet ? 68 : isCompact ? 48 : 58,
                  width: isTablet ? 68 : isCompact ? 48 : 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [role.primaryColor, role.secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(isCompact ? 15 : 19),
                    boxShadow: [
                      BoxShadow(
                        color: role.primaryColor.withOpacity(0.22),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          role.icon,
                          color: Colors.white,
                          size: isTablet ? 33 : isCompact ? 24 : 29,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          height: isCompact ? 19 : 23,
                          width: isCompact ? 19 : 23,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 7,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            role.accentIcon,
                            color: role.primaryColor,
                            size: isCompact ? 11 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isTablet ? 17 : isCompact ? 10 : 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.label,
                        style: TextStyle(
                          color: role.primaryColor,
                          fontSize: isTablet ? 11 : isCompact ? 8.2 : 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                        ),
                      ),
                      SizedBox(height: isCompact ? 3 : 5),
                      Text(
                        role.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: isTablet ? 19 : isCompact ? 14 : 16.5,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: isCompact ? 4 : 6),
                      Text(
                        role.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: isTablet ? 12.8 : isCompact ? 9.2 : 11,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: isCompact ? 6 : 9),
                      Wrap(
                        spacing: isCompact ? 5 : 7,
                        runSpacing: 4,
                        children: [
                          _miniBenefit(
                            role.benefitOne,
                            role.primaryColor,
                            isCompact: isCompact,
                            isTablet: isTablet,
                          ),
                          _miniBenefit(
                            role.benefitTwo,
                            role.primaryColor,
                            isCompact: isCompact,
                            isTablet: isTablet,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isCompact ? 7 : 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: isTablet ? 32 : isCompact ? 24 : 28,
                  width: isTablet ? 32 : isCompact ? 24 : 28,
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
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: role.primaryColor.withOpacity(0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: isTablet ? 19 : isCompact ? 14 : 17,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBenefit(
    String label,
    Color color, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 9 : isCompact ? 6 : 8,
        vertical: isTablet ? 6 : isCompact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: color,
            size: isTablet ? 13 : isCompact ? 9 : 11,
          ),
          SizedBox(width: isCompact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              color: _textPrimary,
              fontSize: isTablet ? 10.5 : isCompact ? 7.2 : 8.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustStrip(
    RoleOption role, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : isCompact ? 10 : 13,
        vertical: isTablet ? 13 : isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(isCompact ? 16 : 19),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            height: isTablet ? 38 : isCompact ? 28 : 34,
            width: isTablet ? 38 : isCompact ? 28 : 34,
            decoration: BoxDecoration(
              color: role.primaryColor.withOpacity(0.09),
              borderRadius: BorderRadius.circular(isCompact ? 9 : 11),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: role.primaryColor,
              size: isTablet ? 21 : isCompact ? 15 : 18,
            ),
          ),
          SizedBox(width: isCompact ? 8 : 10),
          Expanded(
            child: Text(
              'Secure profiles, ratings and safer local connections.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textSecondary,
                fontSize: isTablet ? 12 : isCompact ? 8.8 : 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomAction(
    RoleOption role, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        top: isCompact ? 7 : 11,
        bottom: isCompact ? 8 : 16,
      ),
      child: SizedBox(
        width: double.infinity,
        height: isTablet ? 61 : isCompact ? 49 : 57,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [role.primaryColor, role.secondaryColor],
            ),
            borderRadius: BorderRadius.circular(isCompact ? 15 : 18),
            boxShadow: [
              BoxShadow(
                color: role.primaryColor.withOpacity(0.26),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isNavigating ? null : _continue,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isCompact ? 15 : 18),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: Row(
                key: ValueKey('${role.value}-$_isNavigating'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isNavigating)
                    SizedBox(
                      height: isCompact ? 17 : 19,
                      width: isCompact ? 17 : 19,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else ...[
                    Text(
                      role.value == 'customer'
                          ? 'Continue as Customer'
                          : 'Continue as Worker',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : isCompact ? 13 : 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: isCompact ? 7 : 9),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: isTablet ? 21 : isCompact ? 17 : 19,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ambientCircle({
    required double size,
    required Color color,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class RoleOption {
  final String value;
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData accentIcon;
  final Color primaryColor;
  final Color secondaryColor;
  final String benefitOne;
  final String benefitTwo;

  const RoleOption({
    required this.value,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentIcon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.benefitOne,
    required this.benefitTwo,
  });
}
