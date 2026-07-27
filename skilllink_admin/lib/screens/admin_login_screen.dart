import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skilllink_admin/screens/admin_dashboard_screen.dart';

import '../services/admin_auth_service.dart';
import '../widgets/login_form.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final AdminAuthService _authService = AdminAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    if (_authService.currentUser == null) return;

    setState(() => _isLoading = true);
    final admin = await _authService.getCurrentAdmin();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (admin != null) _openDashboard(admin);
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final admin = await _authService.signInAdmin(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      _showMessage('Welcome back, ${admin.name}', isError: false);
      _openDashboard(admin);
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Login complete nahi ho saka. Dobara try karein.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final controller = TextEditingController(
      text: _emailController.text.trim(),
    );

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Reset password',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Admin email',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send reset link'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (email == null || email.isEmpty) return;

    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      _showMessage(
        'Password reset link email par send kar diya gaya hai.',
        isError: false,
      );
    } on AdminAuthException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

void _openDashboard(AdminProfile admin) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => AdminDashboardScreen(
        admin: admin,
        authService: _authService,
      ),
    ),
  );
}

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundDecoration()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) {
                final isDesktop = viewport.maxWidth >= 980;
                final cardHeight = isDesktop
                    ? (viewport.maxHeight - 56).clamp(700.0, 820.0)
                    : null;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 18,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewport.maxHeight - 56,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Container(
                          height: cardHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x180F172A),
                                blurRadius: 55,
                                offset: Offset(0, 22),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: isDesktop
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Expanded(
                                      flex: 11,
                                      child: _DesktopBrandPanel(),
                                    ),
                                    Expanded(
                                      flex: 9,
                                      child: LoginForm(
                                        emailController: _emailController,
                                        passwordController:
                                            _passwordController,
                                        isLoading: _isLoading,
                                        obscurePassword: _obscurePassword,
                                        rememberMe: _rememberMe,
                                        onPasswordVisibilityChanged: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                        onRememberMeChanged: (value) {
                                          setState(() => _rememberMe = value);
                                        },
                                        onLogin: _handleLogin,
                                        onForgotPassword:
                                            _handleForgotPassword,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _MobileBrandHeader(),
                                    LoginForm(
                                      emailController: _emailController,
                                      passwordController: _passwordController,
                                      isLoading: _isLoading,
                                      obscurePassword: _obscurePassword,
                                      rememberMe: _rememberMe,
                                      onPasswordVisibilityChanged: () {
                                        setState(() {
                                          _obscurePassword =
                                              !_obscurePassword;
                                        });
                                      },
                                      onRememberMeChanged: (value) {
                                        setState(() => _rememberMe = value);
                                      },
                                      onLogin: _handleLogin,
                                      onForgotPassword:
                                          _handleForgotPassword,
                                      compact: true,
                                    ),
                                  ],
                                ),
                        ),
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
}

class _DesktopBrandPanel extends StatelessWidget {
  const _DesktopBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(52),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF16A34A),
            Color(0xFF0D9488),
            Color(0xFF0F766E),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -120,
            right: -90,
            child: _GlowCircle(size: 300, opacity: 0.10),
          ),
          const Positioned(
            bottom: -150,
            left: -120,
            child: _GlowCircle(size: 360, opacity: 0.08),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandLogo(),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                  ),
                ),
                child: Text(
                  'POWERING TRUSTED LOCAL SERVICES',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Manage your entire\nservice marketplace.',
                style: GoogleFonts.inter(
                  fontSize: 43,
                  height: 1.12,
                  letterSpacing: -1.6,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Monitor users, workers, jobs, reports and platform activity from one secure dashboard.',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.80),
                ),
              ),
              const SizedBox(height: 30),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FeatureBadge(
                    icon: Icons.groups_2_outlined,
                    label: 'Users',
                  ),
                  _FeatureBadge(
                    icon: Icons.work_outline_rounded,
                    label: 'Jobs',
                  ),
                  _FeatureBadge(
                    icon: Icons.analytics_outlined,
                    label: 'Analytics',
                  ),
                  _FeatureBadge(
                    icon: Icons.security_rounded,
                    label: 'Safety',
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Secured with Firebase Authentication',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  const _MobileBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 25, 26, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
        ),
      ),
      child: const _BrandLogo(),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.link_rounded,
            color: Color(0xFF16A34A),
            size: 29,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SkillLink',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
                color: Colors.white,
              ),
            ),
            Text(
              'ADMIN CONSOLE',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -160,
          left: -100,
          child: Container(
            height: 400,
            width: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF16A34A).withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -180,
          right: -130,
          child: Container(
            height: 430,
            width: 430,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withOpacity(0.07),
            ),
          ),
        ),
      ],
    );
  }
}

