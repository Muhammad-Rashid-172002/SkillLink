import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
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
          'Explore skilled painters, electricians, plumbers, carpenters and more with verified profiles and customer ratings.',
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF06B6D4),
      featureOne: 'Verified worker profiles',
      featureTwo: 'Ratings and reviews',
    ),
    OnboardingData(
      icon: Icons.assignment_ind_rounded,
      badgeIcon: Icons.handyman_rounded,
      eyebrow: 'POST IN MINUTES',
      title: 'Share your job and\nreceive worker offers',
      subtitle:
          'Describe the work, set your budget, add location details and connect with available professionals.',
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF059669),
      featureOne: 'Simple job posting',
      featureTwo: 'Multiple worker offers',
    ),
    OnboardingData(
      icon: Icons.verified_user_rounded,
      badgeIcon: Icons.chat_bubble_rounded,
      eyebrow: 'WORK WITH CONFIDENCE',
      title: 'Compare, chat and\nhire with confidence',
      subtitle:
          'Review worker experience, communicate safely and manage your job from request to completion.',
      primaryColor: Color(0xFFF97316),
      secondaryColor: Color(0xFFEA580C),
      featureOne: 'Secure in-app chat',
      featureTwo: 'Transparent job progress',
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
      duration: const Duration(milliseconds: 520),
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
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const RoleSelectionScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePage = _pages[_currentIndex];
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -130,
            child: _ambientCircle(
              size: 310,
              color: activePage.primaryColor.withOpacity(0.10),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -130,
            child: _ambientCircle(
              size: 320,
              color: activePage.secondaryColor.withOpacity(0.08),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _topBar(activePage),
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
                        screenSize: size,
                      );
                    },
                  ),
                ),
                _bottomSection(activePage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(OnboardingData page) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      page.primaryColor,
                      page.secondaryColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: page.primaryColor.withOpacity(0.22),
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
                'SkillLink',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: _skip,
            style: TextButton.styleFrom(
              foregroundColor: _textSecondary,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(
                fontSize: 12.5,
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
    required Size screenSize,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationHeight =
            constraints.maxHeight < 580 ? 260.0 : 315.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _illustrationCard(
                  item: item,
                  height: illustrationHeight,
                  width: screenSize.width,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: item.primaryColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: item.primaryColor.withOpacity(0.12),
                    ),
                  ),
                  child: Text(
                    item.eyebrow,
                    style: TextStyle(
                      color: item.primaryColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 30,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 14.2,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _featurePill(
                        item.featureOne,
                        item.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _featurePill(
                        item.featureTwo,
                        item.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _illustrationCard({
    required OnboardingData item,
    required double height,
    required double width,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.primaryColor,
            item.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: item.primaryColor.withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -65,
            right: -55,
            child: Container(
              height: 190,
              width: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -45,
            child: Container(
              height: 190,
              width: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 26,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Trusted platform',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 176,
                  width: 176,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  height: 142,
                  width: 142,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(42),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.24),
                      width: 1.4,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(42),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 10,
                        sigmaY: 10,
                      ),
                      child: Icon(
                        item.icon,
                        color: Colors.white,
                        size: 72,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 28,
            bottom: 28,
            child: Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                item.badgeIcon,
                color: item.primaryColor,
                size: 25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featurePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.check_rounded,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 10.8,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomSection(OnboardingData page) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      decoration: const BoxDecoration(
        color: _background,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${_currentIndex + 1} of ${_pages.length}',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: List.generate(
                    _pages.length,
                    (index) {
                      final isActive = _currentIndex == index;

                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          margin: EdgeInsets.only(
                            right: index == _pages.length - 1 ? 0 : 7,
                          ),
                          height: 5,
                          decoration: BoxDecoration(
                            color: isActive
                                ? page.primaryColor
                                : const Color(0xFFDCE3EC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isNavigating ? null : _nextPage,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: page.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    page.primaryColor.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                shadowColor: page.primaryColor.withOpacity(0.25),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentIndex == _pages.length - 1
                        ? 'Get started'
                        : 'Continue',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Icon(
                    _currentIndex == _pages.length - 1
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    size: 19,
                  ),
                ],
              ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
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
  final String featureOne;
  final String featureTwo;

  const OnboardingData({
    required this.icon,
    required this.badgeIcon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.featureOne,
    required this.featureTwo,
  });
}
