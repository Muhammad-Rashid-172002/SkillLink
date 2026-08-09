import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color _background = Color(0xFFF6F8FC);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF101828);
  static const Color _textSecondary = Color(0xFF667085);
  static const Color _border = Color(0xFFE7ECF3);

  final PageController _pageController = PageController();

  int _currentIndex = 0;
  bool _isNavigating = false;

  final List<OnboardingData> _pages = const [
    OnboardingData(
      icon: Icons.search_rounded,
      badgeIcon: Icons.location_on_rounded,
      eyebrow: 'DISCOVER LOCAL TALENT',
      title: 'Find trusted workers\nnear your location',
      subtitle:
          'Explore skilled professionals near you with verified profiles, transparent ratings and reliable service history.',
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF06B6D4),
      accentColor: Color(0xFF7DD3FC),
      featureOne: 'Verified professionals',
      featureTwo: 'Real customer reviews',
      floatingTitle: 'Nearby experts',
      floatingSubtitle: 'Ready to help today',
      statValue: '4.9',
      statLabel: 'Average rating',
    ),
    OnboardingData(
      icon: Icons.assignment_ind_rounded,
      badgeIcon: Icons.handyman_rounded,
      eyebrow: 'POST IN MINUTES',
      title: 'Share your job and\nreceive worker offers',
      subtitle:
          'Describe the task, set your budget and compare offers from available professionals without wasting time.',
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF059669),
      accentColor: Color(0xFF6EE7B7),
      featureOne: 'Simple job posting',
      featureTwo: 'Competitive offers',
      floatingTitle: '3 new offers',
      floatingSubtitle: 'For your plumbing job',
      statValue: '< 5 min',
      statLabel: 'Average response',
    ),
    OnboardingData(
      icon: Icons.verified_user_rounded,
      badgeIcon: Icons.chat_bubble_rounded,
      eyebrow: 'WORK WITH CONFIDENCE',
      title: 'Compare, chat and\nhire with confidence',
      subtitle:
          'Review experience, communicate safely and track every stage of your job from request to completion.',
      primaryColor: Color(0xFFF97316),
      secondaryColor: Color(0xFFEA580C),
      accentColor: Color(0xFFFDBA74),
      featureOne: 'Secure in-app chat',
      featureTwo: 'Live job progress',
      floatingTitle: 'Job protected',
      floatingSubtitle: 'Track every update',
      statValue: '100%',
      statLabel: 'Progress visibility',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_isNavigating) return;

    if (_currentIndex == _pages.length - 1) {
      await _openRoleSelection();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
    await _openRoleSelection();
  }

  Future<void> _openRoleSelection() async {
    if (_isNavigating) return;

    setState(() => _isNavigating = true);

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: const RoleSelectionScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePage = _pages[_currentIndex];

    return Scaffold(
      backgroundColor: _background,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _background,
              activePage.primaryColor.withOpacity(0.045),
              activePage.secondaryColor.withOpacity(0.025),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -130,
              right: -130,
              child: _ambientCircle(
                size: 330,
                color: activePage.primaryColor.withOpacity(0.10),
              ),
            ),
            Positioned(
              bottom: -170,
              left: -130,
              child: _ambientCircle(
                size: 340,
                color: activePage.secondaryColor.withOpacity(0.08),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  final isTablet = width >= 600;
                  final isCompact = height < 700 || width < 360;
                  final horizontalPadding = isTablet ? 34.0 : 18.0;
                  final contentMaxWidth = isTablet ? 660.0 : 520.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Column(
                          children: [
                            _topBar(
                              activePage,
                              isCompact: isCompact,
                              isTablet: isTablet,
                            ),
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _pages.length,
                                onPageChanged: (index) {
                                  setState(() => _currentIndex = index);
                                },
                                itemBuilder: (context, index) {
                                  return _onboardingPage(
                                    item: _pages[index],
                                    pageIndex: index,
                                    isCompact: isCompact,
                                    isTablet: isTablet,
                                  );
                                },
                              ),
                            ),
                            _bottomSection(
                              activePage,
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
      ),
    );
  }

  Widget _topBar(
    OnboardingData page, {
    required bool isCompact,
    required bool isTablet,
  }) {
    final logoSize = isTablet
        ? 50.0
        : isCompact
        ? 38.0
        : 44.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(0, isCompact ? 8 : 14, 0, isCompact ? 2 : 6),
      child: Row(
        children: [
          Container(
            height: logoSize,
            width: logoSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [page.primaryColor, page.secondaryColor],
              ),
              borderRadius: BorderRadius.circular(isTablet ? 17 : 15),
              border: Border.all(
                color: Colors.white.withOpacity(0.70),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: page.primaryColor.withOpacity(0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.handyman_rounded,
              color: Colors.white,
              size: isTablet
                  ? 26
                  : isCompact
                  ? 20
                  : 23,
            ),
          ),
          SizedBox(width: isCompact ? 9 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SkillNova',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: isTablet
                      ? 24
                      : isCompact
                      ? 18.5
                      : 21.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  height: 1,
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(height: 4),
                const Text(
                  'Trusted local services',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: _isNavigating ? null : _skip,
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              disabledForegroundColor: _textSecondary.withOpacity(0.45),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 10 : 13,
                vertical: isCompact ? 8 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Skip',
              style: TextStyle(
                fontSize: isTablet
                    ? 14
                    : isCompact
                    ? 11.5
                    : 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _onboardingPage({
    required OnboardingData item,
    required int pageIndex,
    required bool isCompact,
    required bool isTablet,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetHeight = isTablet
            ? 660.0
            : isCompact
            ? 500.0
            : 600.0;

        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth,
              height: targetHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _illustrationCard(
                    item: item,
                    pageIndex: pageIndex,
                    height: isTablet
                        ? 305
                        : isCompact
                        ? 190
                        : 255,
                    isCompact: isCompact,
                    isTablet: isTablet,
                  ),
                  SizedBox(
                    height: isTablet
                        ? 24
                        : isCompact
                        ? 13
                        : 20,
                  ),
                  _eyebrowBadge(item, isCompact: isCompact, isTablet: isTablet),
                  SizedBox(
                    height: isTablet
                        ? 15
                        : isCompact
                        ? 9
                        : 12,
                  ),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: isTablet
                          ? 35
                          : isCompact
                          ? 23.5
                          : 29,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.9,
                    ),
                  ),
                  SizedBox(
                    height: isTablet
                        ? 13
                        : isCompact
                        ? 8
                        : 11,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet
                          ? 46
                          : isCompact
                          ? 4
                          : 14,
                    ),
                    child: Text(
                      item.subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: isTablet
                            ? 15.5
                            : isCompact
                            ? 11.5
                            : 13.5,
                        height: isCompact ? 1.35 : 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: isTablet
                        ? 19
                        : isCompact
                        ? 11
                        : 16,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _featureCard(
                          item.featureOne,
                          item.primaryColor,
                          isCompact: isCompact,
                          isTablet: isTablet,
                        ),
                      ),
                      SizedBox(width: isCompact ? 8 : 10),
                      Expanded(
                        child: _featureCard(
                          item.featureTwo,
                          item.primaryColor,
                          isCompact: isCompact,
                          isTablet: isTablet,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _eyebrowBadge(
    OnboardingData item, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 13,
        vertical: isCompact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: item.primaryColor.withOpacity(0.085),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: item.primaryColor.withOpacity(0.13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isCompact ? 5 : 6,
            height: isCompact ? 5 : 6,
            decoration: BoxDecoration(
              color: item.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isCompact ? 6 : 8),
          Text(
            item.eyebrow,
            style: TextStyle(
              color: item.primaryColor,
              fontSize: isTablet
                  ? 12
                  : isCompact
                  ? 9
                  : 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _illustrationCard({
    required OnboardingData item,
    required int pageIndex,
    required double height,
    required bool isCompact,
    required bool isTablet,
  }) {
    final mainCircle = isTablet
        ? 176.0
        : isCompact
        ? 112.0
        : 148.0;
    final iconBox = isTablet
        ? 138.0
        : isCompact
        ? 88.0
        : 116.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [item.primaryColor, item.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(isCompact ? 25 : 34),
        border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: item.primaryColor.withOpacity(0.28),
            blurRadius: isCompact ? 22 : 34,
            spreadRadius: -8,
            offset: Offset(0, isCompact ? 12 : 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isCompact ? 25 : 34),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  lineColor: Colors.white.withOpacity(0.065),
                ),
              ),
            ),
            Positioned(
              top: -70,
              right: -55,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: -50,
              child: Container(
                height: 210,
                width: 210,
                decoration: BoxDecoration(
                  color: item.accentColor.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: isCompact ? 13 : 20,
              left: isCompact ? 13 : 20,
              child: _glassChip(
                icon: Icons.verified_rounded,
                label: 'Trusted platform',
                isCompact: isCompact,
              ),
            ),
            Positioned(
              top: isCompact ? 13 : 20,
              right: isCompact ? 13 : 20,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 10,
                  vertical: isCompact ? 5 : 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(
                  '0${pageIndex + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompact ? 9 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: mainCircle,
                    width: mainCircle,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  Container(
                    height: iconBox,
                    width: iconBox,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(isCompact ? 30 : 42),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.26),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isCompact ? 30 : 42),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Icon(
                          item.icon,
                          color: Colors.white,
                          size: isTablet
                              ? 68
                              : isCompact
                              ? 46
                              : 60,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: isCompact ? 13 : 20,
              bottom: isCompact ? 13 : 20,
              child: _floatingInfoCard(
                item,
                isCompact: isCompact,
                isTablet: isTablet,
              ),
            ),
            Positioned(
              right: isCompact ? 14 : 22,
              bottom: isCompact ? 14 : 22,
              child: Container(
                height: isTablet
                    ? 58
                    : isCompact
                    ? 42
                    : 52,
                width: isTablet
                    ? 58
                    : isCompact
                    ? 42
                    : 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isCompact ? 14 : 18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.17),
                      blurRadius: 20,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Icon(
                  item.badgeIcon,
                  color: item.primaryColor,
                  size: isTablet
                      ? 27
                      : isCompact
                      ? 19
                      : 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassChip({
    required IconData icon,
    required String label,
    required bool isCompact,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 9 : 12,
            vertical: isCompact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: isCompact ? 12 : 15),
              SizedBox(width: isCompact ? 5 : 7),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 8.5 : 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingInfoCard(
    OnboardingData item, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isCompact ? 13 : 17),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet
                ? 190
                : isCompact
                ? 118
                : 160,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 9 : 12,
            vertical: isCompact ? 7 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.93),
            borderRadius: BorderRadius.circular(isCompact ? 13 : 17),
            border: Border.all(color: Colors.white.withOpacity(0.75)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isCompact ? 26 : 34,
                height: isCompact ? 26 : 34,
                decoration: BoxDecoration(
                  color: item.primaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: item.primaryColor,
                  size: isCompact ? 15 : 18,
                ),
              ),
              SizedBox(width: isCompact ? 7 : 9),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.floatingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: isTablet
                            ? 11.5
                            : isCompact
                            ? 8.5
                            : 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.floatingSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: isTablet
                            ? 9.5
                            : isCompact
                            ? 7
                            : 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard(
    String label,
    Color color, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: isCompact ? 47 : 58),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 9 : 12,
        vertical: isCompact ? 8 : 11,
      ),
      decoration: BoxDecoration(
        color: _surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(isCompact ? 14 : 17),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: isTablet
                ? 31
                : isCompact
                ? 24
                : 29,
            width: isTablet
                ? 31
                : isCompact
                ? 24
                : 29,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(isCompact ? 8 : 9),
            ),
            child: Icon(
              Icons.check_rounded,
              color: color,
              size: isTablet
                  ? 18
                  : isCompact
                  ? 14
                  : 17,
            ),
          ),
          SizedBox(width: isCompact ? 7 : 9),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textPrimary,
                fontSize: isTablet
                    ? 12.2
                    : isCompact
                    ? 9.3
                    : 10.8,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomSection(
    OnboardingData page, {
    required bool isCompact,
    required bool isTablet,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        isCompact ? 6 : 10,
        0,
        isCompact ? 9 : 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 10,
                  vertical: isCompact ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  '${_currentIndex + 1}/${_pages.length}',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: isTablet
                        ? 12.5
                        : isCompact
                        ? 9.5
                        : 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 9 : 12),
              Expanded(
                child: Row(
                  children: List.generate(_pages.length, (index) {
                    final isActive = _currentIndex == index;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 340),
                        curve: Curves.easeOutCubic,
                        margin: EdgeInsets.only(
                          right: index == _pages.length - 1
                              ? 0
                              : isCompact
                              ? 5
                              : 7,
                        ),
                        height: isActive
                            ? (isCompact ? 5 : 6)
                            : (isCompact ? 4 : 5),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? LinearGradient(
                                  colors: [
                                    page.primaryColor,
                                    page.secondaryColor,
                                  ],
                                )
                              : null,
                          color: isActive ? null : const Color(0xFFDCE3EC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 16),
          SizedBox(
            width: double.infinity,
            height: isTablet
                ? 62
                : isCompact
                ? 49
                : 57,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [page.primaryColor, page.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(isCompact ? 15 : 18),
                boxShadow: [
                  BoxShadow(
                    color: page.primaryColor.withOpacity(0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isNavigating ? null : _nextPage,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white.withOpacity(0.70),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isCompact ? 15 : 18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isNavigating) ...[
                      SizedBox(
                        width: isCompact ? 15 : 18,
                        height: isCompact ? 15 : 18,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: isCompact ? 8 : 10),
                    ],
                    Text(
                      _currentIndex == _pages.length - 1
                          ? 'Start exploring'
                          : 'Continue',
                      style: TextStyle(
                        fontSize: isTablet
                            ? 16.5
                            : isCompact
                            ? 13
                            : 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (!_isNavigating) ...[
                      SizedBox(width: isCompact ? 8 : 10),
                      Container(
                        width: isCompact ? 26 : 30,
                        height: isCompact ? 26 : 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          _currentIndex == _pages.length - 1
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          size: isTablet
                              ? 19
                              : isCompact
                              ? 15
                              : 17,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ambientCircle({required double size, required Color color}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color lineColor;

  const _GridPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    const spacing = 30.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class OnboardingData {
  final IconData icon;
  final IconData badgeIcon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String featureOne;
  final String featureTwo;
  final String floatingTitle;
  final String floatingSubtitle;
  final String statValue;
  final String statLabel;

  const OnboardingData({
    required this.icon,
    required this.badgeIcon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.featureOne,
    required this.featureTwo,
    required this.floatingTitle,
    required this.floatingSubtitle,
    required this.statValue,
    required this.statLabel,
  });
}
