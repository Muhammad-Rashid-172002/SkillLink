import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color _green = Color(0xFF059669);
  static const Color _green2 = Color(0xFF10B981);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _line = Color(0xFFE8EEF2);

  final PageController _controller = PageController();
  int _index = 0;
  bool _opening = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_opening) return;
    if (_index == 2) {
      await _openRoleSelection();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 470),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openRoleSelection() async {
    if (_opening) return;
    setState(() => _opening = true);

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: const RoleSelectionScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkPage = _index == 2;

    return Scaffold(
      backgroundColor: isDarkPage ? Colors.black : const Color(0xFFFBFCFD),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (value) => setState(() => _index = value),
              children: const [
                _FindExpertsPage(),
                _PostJobPage(),
                _HireConfidencePage(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                index: _index,
                loading: _opening,
                dark: isDarkPage,
                onNext: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final bool dark;
  final VoidCallback? onSkip;

  const _BrandHeader({required this.dark, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : const Color(0xFF0F172A);
    final subColor = dark ? Colors.white70 : const Color(0xFF64748B);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withOpacity(.20),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              height: 1,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SkillNova',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
            Text(
              'Local Skills. Real Solutions.',
              style: TextStyle(
                color: subColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: onSkip,
          child: Text(
            'Skip',
            style: TextStyle(
              color: dark ? Colors.white : const Color(0xFF475569),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FindExpertsPage extends StatelessWidget {
  const _FindExpertsPage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxHeight < 760;

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, compact ? 14 : 20, 22, 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BrandHeader(dark: false, onSkip: () => _skipFrom(context)),
                SizedBox(height: compact ? 24 : 34),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Find Trusted\n',
                        style: TextStyle(color: Color(0xFF047857)),
                      ),
                      TextSpan(text: 'Local Experts'),
                    ],
                  ),
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 38,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Skilled professionals in your area,\nready to help when you need them.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: compact ? 22 : 28),
                const _LocationPill(),
                const SizedBox(height: 12),
                SizedBox(
                  height: compact ? 310 : 365,
                  child: const _ExpertMapCard(),
                ),
                const SizedBox(height: 14),
                const _ThreeFeatureStrip(
                  items: [
                    _FeatureStripItem(
                      icon: Icons.verified_user_rounded,
                      label: 'Verified\nProfessionals',
                    ),
                    _FeatureStripItem(
                      icon: Icons.star_rounded,
                      label: 'Real Customer\nReviews',
                    ),
                    _FeatureStripItem(
                      icon: Icons.location_on_rounded,
                      label: 'Nearby in\nYour Area',
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
}

class _PostJobPage extends StatelessWidget {
  const _PostJobPage();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxHeight < 760;

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, compact ? 14 : 20, 22, 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BrandHeader(dark: false, onSkip: () => _skipFrom(context)),
                SizedBox(height: compact ? 24 : 32),
                const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Post Your Job\nGet '),
                      TextSpan(
                        text: 'Multiple Offers',
                        style: TextStyle(color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 36,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tell us what you need and receive\nquotes from trusted professionals.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: compact ? 18 : 24),
                const _JobCard(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 16,
                        color: Color(0xFF34D399),
                      ),
                      SizedBox(width: 7),
                      Text(
                        '3 offers received',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _OfferCard(
                  asset: 'assets/onboarding/worker_plumber.png',
                  name: 'Ahmed Services',
                  price: 'PKR 3,500',
                  rating: '4.9',
                  reviews: '120 reviews',
                ),
                const SizedBox(height: 9),
                const _OfferCard(
                  asset: 'assets/onboarding/worker_ac.png',
                  name: 'CoolFix Experts',
                  price: 'PKR 4,000',
                  rating: '4.8',
                  reviews: '98 reviews',
                ),
                const SizedBox(height: 9),
                const _OfferCard(
                  asset: 'assets/onboarding/worker_painter.png',
                  name: 'Shahzad Technician',
                  price: 'PKR 4,500',
                  rating: '4.7',
                  reviews: '76 reviews',
                ),
                const SizedBox(height: 14),
                const _ThreeFeatureStrip(
                  items: [
                    _FeatureStripItem(
                      icon: Icons.bolt_rounded,
                      label: 'Simple\nJob Posting',
                    ),
                    _FeatureStripItem(
                      icon: Icons.groups_rounded,
                      label: 'Multiple\nOffers',
                    ),
                    _FeatureStripItem(
                      icon: Icons.bar_chart_rounded,
                      label: 'Compare\n& Choose',
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
}

class _HireConfidencePage extends StatelessWidget {
  const _HireConfidencePage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/onboarding/worker_hero.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(.16),
                Colors.black.withOpacity(.28),
                Colors.black.withOpacity(.78),
                Colors.black.withOpacity(.94),
              ],
              stops: const [0, .28, .60, 1],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxHeight < 760;

            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, compact ? 14 : 20, 22, 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BrandHeader(dark: true, onSkip: () => _skipFrom(context)),
                    SizedBox(height: compact ? 220 : 280),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Hire with\n'),
                          TextSpan(
                            text: 'Confidence',
                            style: TextStyle(color: Color(0xFFB7F7DA)),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Chat, track progress and complete\nyour job safely with secure payments.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _ProgressGlassCard(),
                    const SizedBox(height: 14),
                    const _FourDarkFeatures(),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

void _skipFrom(BuildContext context) {
  final state = context.findAncestorStateOfType<_OnboardingScreenState>();
  state?._openRoleSelection();
}

class _LocationPill extends StatelessWidget {
  const _LocationPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6EDF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.location_on_rounded, color: Color(0xFF0F172A), size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Islamabad, Pakistan',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          VerticalDivider(indent: 13, endIndent: 13, color: Color(0xFFE6EDF2)),
          Icon(Icons.my_location_rounded, color: Color(0xFF0F172A), size: 20),
        ],
      ),
    );
  }
}

class _ExpertMapCard extends StatelessWidget {
  const _ExpertMapCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _FakeMap(),
          Positioned(
            top: 22,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(.25),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Near you',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.near_me_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 22,
            top: 88,
            child: _WorkerPin(
              asset: 'assets/onboarding/worker_electrician.png',
              job: 'Electrician',
              rating: '4.9',
              color: Color(0xFFF59E0B),
            ),
          ),
          const Positioned(
            right: 20,
            top: 105,
            child: _WorkerPin(
              asset: 'assets/onboarding/worker_plumber.png',
              job: 'Plumber',
              rating: '4.8',
              color: Color(0xFF2563EB),
            ),
          ),
          const Positioned(
            left: 38,
            bottom: 28,
            child: _WorkerPin(
              asset: 'assets/onboarding/worker_ac.png',
              job: 'AC Technician',
              rating: '4.7',
              color: Color(0xFF0F766E),
            ),
          ),
          const Positioned(
            right: 34,
            bottom: 42,
            child: _WorkerPin(
              asset: 'assets/onboarding/worker_painter.png',
              job: 'Painter',
              rating: '4.8',
              color: Color(0xFF10B981),
            ),
          ),
          Center(
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(.35),
                    blurRadius: 12,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeMap extends StatelessWidget {
  const _FakeMap();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FakeMapPainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F7F8), Color(0xFFE9F3EF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _FakeMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final thin = Paint()
      ..color = const Color(0xFFDDE8E4)
      ..strokeWidth = 1.4;

    for (double y = 36; y < size.height; y += 52) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 18), thin);
    }

    for (double x = 28; x < size.width; x += 65) {
      canvas.drawLine(Offset(x, 0), Offset(x - 18, size.height), thin);
    }

    canvas.drawLine(
      Offset(-20, size.height * .35),
      Offset(size.width + 30, size.height * .66),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .18, -20),
      Offset(size.width * .52, size.height + 20),
      road,
    );
    canvas.drawLine(
      Offset(size.width * .82, -20),
      Offset(size.width * .57, size.height + 20),
      road,
    );

    final green = Paint()..color = const Color(0xFFDDF3E8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .64, size.height * .10, 90, 70),
        const Radius.circular(20),
      ),
      green,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .03, size.height * .60, 76, 54),
        const Radius.circular(18),
      ),
      green,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WorkerPin extends StatelessWidget {
  final String asset;
  final String job;
  final String rating;
  final Color color;

  const _WorkerPin({
    required this.asset,
    required this.job,
    required this.rating,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 62,
          height: 62,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x160F172A),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  job,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rating,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EDF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.ac_unit_rounded,
                  color: Color(0xFF64748B),
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AC Service Needed',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Islamabad, F-10',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Need AC cleaning and gas refill\nfor 1.5 ton inverter.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 13),
          const Row(
            children: [
              Expanded(
                child: _MiniMeta(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Budget',
                  value: 'PKR 3,000 – 5,000',
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: _MiniMeta(
                  icon: Icons.calendar_month_rounded,
                  label: 'Date',
                  value: 'This week',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Post Job',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF0F172A), size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String asset;
  final String name;
  final String price;
  final String rating;
  final String reviews;

  const _OfferCard({
    required this.asset,
    required this.name,
    required this.price,
    required this.rating,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE8EEF2)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(asset, width: 46, height: 46, fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$rating ($reviews)',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Color(0xFF047857),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF7EC),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'View Offer',
                  style: TextStyle(
                    color: Color(0xFF047857),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressGlassCard extends StatelessWidget {
  const _ProgressGlassCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.30),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(.16)),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 17,
                top: 20,
                bottom: 24,
                child: Container(
                  width: 2,
                  color: Colors.white.withOpacity(.20),
                ),
              ),
              const Column(
                children: [
                  _TimelineRow(
                    icon: Icons.check_rounded,
                    active: true,
                    title: 'Worker hired',
                    subtitle: '10:20 AM',
                  ),
                  SizedBox(height: 17),
                  _TimelineRow(
                    icon: Icons.check_rounded,
                    active: true,
                    title: 'On the way',
                    subtitle: '10:45 AM',
                  ),
                  SizedBox(height: 17),
                  _TimelineRow(
                    icon: Icons.circle,
                    active: true,
                    title: 'Work in progress',
                    subtitle: 'AC service in progress',
                  ),
                  SizedBox(height: 17),
                  _TimelineRow(
                    icon: Icons.circle_outlined,
                    active: false,
                    title: 'Completed',
                    subtitle: '',
                  ),
                ],
              ),
              Positioned(
                top: 51,
                right: 0,
                child: Container(
                  width: 148,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: AssetImage(
                          'assets/onboarding/worker_plumber.png',
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "I'm on the way!",
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'See you in 15 minutes.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 8.5,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String title;
  final String subtitle;

  const _TimelineRow({
    required this.icon,
    required this.active,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF10B981)
                : Colors.white.withOpacity(.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? const Color(0xFF34D399) : Colors.white24,
              width: 2,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FourDarkFeatures extends StatelessWidget {
  const _FourDarkFeatures();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_rounded, 'Secure\nPayments'),
      (Icons.chat_bubble_rounded, 'In-app\nChat'),
      (Icons.schedule_rounded, 'Live Job\nTracking'),
      (Icons.headset_mic_rounded, '24/7\nSupport'),
    ];

    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Expanded(
            child: Container(
              height: 86,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.34),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.10)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(items[i].$1, color: Colors.white, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _ThreeFeatureStrip extends StatelessWidget {
  final List<_FeatureStripItem> items;

  const _ThreeFeatureStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EEF2)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(child: items[i]),
            if (i != items.length - 1)
              Container(width: 1, height: 46, color: const Color(0xFFE8EEF2)),
          ],
        ],
      ),
    );
  }
}

class _FeatureStripItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureStripItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF059669), size: 25),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 9.5,
            height: 1.18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final bool loading;
  final bool dark;
  final VoidCallback onNext;

  const _BottomBar({
    required this.index,
    required this.loading,
    required this.dark,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  Colors.black.withOpacity(0),
                  Colors.black.withOpacity(.88),
                  Colors.black,
                ]
              : [
                  const Color(0xFFFBFCFD).withOpacity(0),
                  const Color(0xFFFBFCFD),
                  const Color(0xFFFBFCFD),
                ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1}/3',
                  style: TextStyle(
                    color: dark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 22),
                Row(
                  children: List.generate(3, (i) {
                    final active = i == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: active ? 28 : 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF10B981)
                            : (dark ? Colors.white30 : const Color(0xFFD7DEE5)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: loading ? null : onNext,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 58,
                    width: index == 2 ? 210 : 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(index == 2 ? 22 : 29),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withOpacity(.25),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : index == 2
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                              ),
                            ],
                          )
                        : const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
            if (index == 2) ...[
              const SizedBox(height: 10),
              const Text(
                'Better Homes. Stronger Communities.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
