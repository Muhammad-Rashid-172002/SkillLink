import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_link/core/auth/auth_session_service.dart';
import 'package:skill_link/core/auth/session_router.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_brand.dart';

/// Launch screen + session restoration.
///
/// The session is resolved in parallel with a short brand animation, so a
/// returning customer or worker lands directly on their own dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
  );
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  String _status = 'Getting things ready';
  bool _showStatus = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _statusTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showStatus = true);
    });
    _start();
  }

  Future<void> _start() async {
    final minimumDisplay = Future<void>.delayed(
      const Duration(milliseconds: 1100),
    );
    if (AuthSessionService.instance.currentUser != null) {
      _status = 'Restoring your session';
    }
    final session = await AuthSessionService.instance.resolve();
    await minimumDisplay;
    if (!mounted) return;
    SessionRouter.go(context, session);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: SkillNovaColors.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.25),
                  radius: 1.1,
                  colors: [Color(0xFF13305E), SkillNovaColors.ink],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1E7BFF,
                            ).withValues(alpha: 0.35),
                            blurRadius: 60,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const SkillNovaLogo(size: 88),
                    ),
                  ),
                  const SizedBox(height: SkillNovaSpacing.lg),
                  FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        Text(
                          'SkillNova',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: SkillNovaSpacing.xs),
                        Text(
                          'Trusted local pros, on demand',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                  SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        color: const Color(0xFF4FD1C5),
                      ),
                    ),
                  ),
                  const SizedBox(height: SkillNovaSpacing.sm),
                  AnimatedOpacity(
                    opacity: _showStatus ? 1 : 0,
                    duration: SkillNovaMotion.medium,
                    child: Text(
                      _status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: SkillNovaSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
