import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/services/skillnova_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _leaving = false;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      eyebrow: 'Discover',
      title: 'Skilled pros, right around the corner',
      body:
          'Plumbers, electricians, AC technicians, painters and more — '
          'find the right person near you in seconds.',
      visual: _Visual.network,
    ),
    _OnboardingPageData(
      eyebrow: 'Request',
      title: 'Describe the job once, get matched fast',
      body:
          'Tell us what you need, where and when. Nearby professionals are '
          'notified and you choose who to hire.',
      visual: _Visual.request,
    ),
    _OnboardingPageData(
      eyebrow: 'Trust',
      title: 'Verified people. Tracked jobs. Real reviews.',
      body:
          'Workers verify their identity, every job is tracked from start to '
          'finish, and you can chat or raise an alert anytime.',
      visual: _Visual.trust,
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final asset in const [
      'assets/onboarding/pro_hero.jpg',
      'assets/onboarding/pro_plumber.png',
      'assets/onboarding/pro_electrician.png',
      'assets/onboarding/pro_ac.png',
      'assets/onboarding/pro_painter.png',
    ]) {
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_leaving) return;
    _leaving = true;
    await skillNovaPreferences.markOnboardingCompleted();
    if (!mounted) return;
    SessionRouter.replaceAll(context, const RoleSelectionScreen());
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: SkillNovaMotion.of(context, SkillNovaMotion.slow),
      curve: SkillNovaMotion.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= SkillNovaBreakpoints.tablet;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    const SkillNovaWordmark(size: 30),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: SkillNovaMotion.fast,
                      child: TextButton(
                        onPressed: _isLast ? null : _finish,
                        child: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, i) =>
                      _OnboardingPage(data: _pages[i], wide: wide),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Row(
                    children: [
                      _PageDots(count: _pages.length, index: _index),
                      const Spacer(),
                      SizedBox(
                        width: _isLast ? 180 : 140,
                        child: PrimaryButton(
                          label: _isLast ? 'Get started' : 'Next',
                          icon: _isLast ? null : Icons.arrow_forward_rounded,
                          fullWidth: true,
                          onPressed: _next,
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

enum _Visual { network, request, trust }

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.visual,
  });

  final String eyebrow;
  final String title;
  final String body;
  final _Visual visual;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.wide});

  final _OnboardingPageData data;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = switch (data.visual) {
      _Visual.network => const _NetworkVisual(),
      _Visual.request => const _RequestVisual(),
      _Visual.trust => const _TrustVisual(),
    };
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.eyebrow.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: SkillNovaSpacing.sm),
        Text(
          data.title,
          style: wide
              ? theme.textTheme.displaySmall
              : theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: SkillNovaSpacing.sm),
        Text(
          data.body,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (wide) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Expanded(child: Center(child: visual)),
                const SizedBox(width: 48),
                Expanded(child: copy),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: (constraints.maxHeight * 0.55).clamp(240.0, 380.0),
                child: Center(child: visual),
              ),
              const SizedBox(height: SkillNovaSpacing.xl),
              copy,
            ],
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: SkillNovaMotion.of(context, SkillNovaMotion.medium),
              curve: SkillNovaMotion.standard,
              margin: const EdgeInsets.only(right: 6),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? colors.primary : colors.outline,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Visuals -----------------------------------------------------------------

class _VisualFrame extends StatelessWidget {
  const _VisualFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SkillNovaRadius.xlarge),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primaryContainer,
              colors.secondaryContainer.withValues(alpha: 0.8),
            ],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
      ),
    );
  }
}

class _NetworkVisual extends StatelessWidget {
  const _NetworkVisual();

  @override
  Widget build(BuildContext context) {
    return _VisualFrame(
      child: LayoutBuilder(
        builder: (context, c) {
          final s = c.maxWidth;
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _GridPainter())),
              Center(
                child: Container(
                  width: s * 0.26,
                  height: s * 0.26,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: SkillNovaElevation.floating,
                  ),
                  child: Icon(
                    Icons.my_location_rounded,
                    size: s * 0.11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              _ProBubble(
                left: s * 0.08,
                top: s * 0.1,
                size: s * 0.24,
                asset: 'assets/onboarding/pro_plumber.png',
                label: 'Plumber',
              ),
              _ProBubble(
                right: s * 0.08,
                top: s * 0.14,
                size: s * 0.22,
                asset: 'assets/onboarding/pro_electrician.png',
                label: 'Electrician',
              ),
              _ProBubble(
                left: s * 0.12,
                bottom: s * 0.1,
                size: s * 0.22,
                asset: 'assets/onboarding/pro_ac.png',
                label: 'AC Technician',
              ),
              _ProBubble(
                right: s * 0.1,
                bottom: s * 0.12,
                size: s * 0.24,
                asset: 'assets/onboarding/pro_painter.png',
                label: 'Painter',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProBubble extends StatelessWidget {
  const _ProBubble({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.size,
    required this.asset,
    required this.label,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double size;
  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: SkillNovaElevation.subtle,
            ),
            child: ClipOval(
              child: Image.asset(
                asset,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
              boxShadow: SkillNovaElevation.subtle,
            ),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF155EEF).withValues(alpha: 0.08)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF155EEF).withValues(alpha: 0.18);
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.width * 0.24, ring);
    canvas.drawCircle(center, size.width * 0.38, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RequestVisual extends StatelessWidget {
  const _RequestVisual();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    Widget row(IconData icon, String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall),
                Text(
                  value,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _VisualFrame(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(SkillNovaRadius.large),
              boxShadow: SkillNovaElevation.raised,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New request', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (label, selected) in const [
                      ('Plumbing', true),
                      ('Electrical', false),
                      ('AC repair', false),
                    ])
                      Chip(
                        label: Text(label),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: selected
                            ? colors.primary
                            : colors.surfaceContainer,
                        side: BorderSide.none,
                        labelStyle: theme.textTheme.labelMedium?.copyWith(
                          color: selected ? Colors.white : colors.onSurface,
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                row(Icons.edit_note_rounded, 'What needs doing', 'Kitchen tap is leaking'),
                row(Icons.place_outlined, 'Where', 'Your saved address'),
                row(Icons.schedule_rounded, 'When', 'Today, as soon as possible'),
                const SizedBox(height: 10),
                Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
                  ),
                  child: Text(
                    'Send request',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustVisual extends StatelessWidget {
  const _TrustVisual();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget badge(IconData icon, String text, Color color) => Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
        boxShadow: SkillNovaElevation.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );

    return _VisualFrame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/onboarding/pro_hero.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
                stops: [0.45, 1],
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: badge(
              Icons.verified_rounded,
              'Identity verified',
              SkillNovaColors.success,
            ),
          ),
          Positioned(
            right: 16,
            top: 70,
            child: badge(
              Icons.route_rounded,
              'Live job tracking',
              SkillNovaColors.primary,
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: badge(
              Icons.chat_bubble_rounded,
              'Chat in the app',
              SkillNovaColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
