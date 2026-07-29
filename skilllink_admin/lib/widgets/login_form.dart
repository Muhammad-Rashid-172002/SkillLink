import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.rememberMe,
    required this.onPasswordVisibilityChanged,
    required this.onRememberMeChanged,
    required this.onLogin,
    required this.onForgotPassword,
    this.compact = false,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool obscurePassword;
  final bool rememberMe;
  final bool compact;
  final VoidCallback onPasswordVisibilityChanged;
  final ValueChanged<bool> onRememberMeChanged;
  final Future<void> Function() onLogin;
  final Future<void> Function() onForgotPassword;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  Future<void> _submit() async {
    if (widget.isLoading) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onLogin();
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 24 : 52,
        vertical: widget.compact ? 32 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF0D9488)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF16A34A).withOpacity(0.22),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to SkillNova Admin',
                    style: GoogleFonts.inter(
                      fontSize: widget.compact ? 28 : 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Securely access the SkillNova Admin Panel.',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _FieldLabel(text: 'Email address'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    onFieldSubmitted: (_) {
                      _passwordFocusNode.requestFocus();
                    },
                    decoration: _inputDecoration(
                      label: 'Admin email',
                      hint: 'admin@skillnova.com',
                      icon: Icons.alternate_email_rounded,
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return 'Email address enter karein.';
                      }

                      final validEmail = RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email);

                      if (!validEmail) {
                        return 'Valid email address enter karein.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const _FieldLabel(text: 'Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: widget.passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: widget.obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: _inputDecoration(
                      label: 'Password',
                      hint: 'Enter your password',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        tooltip: widget.obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: widget.onPasswordVisibilityChanged,
                        icon: Icon(
                          widget.obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.isEmpty) return 'Password enter karein.';
                      if (password.length < 6) {
                        return 'Password kam az kam 6 characters ka hona chahiye.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _RememberAndForgotRow(
                    rememberMe: widget.rememberMe,
                    isLoading: widget.isLoading,
                    onRememberMeChanged: widget.onRememberMeChanged,
                    onForgotPassword: widget.onForgotPassword,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: widget.isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        disabledBackgroundColor:
                            const Color(0xFF16A34A).withOpacity(0.55),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                        elevation: 0,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: widget.isLoading
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                key: const ValueKey('content'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Continue to Dashboard',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF16A34A),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Access is restricted to authorized SkillNova administrators.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Text(
                      '© ${DateTime.now().year} SkillNova. Secure Admin Portal.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: GoogleFonts.inter(
        color: const Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      prefixIconColor: const Color(0xFF64748B),
      border: border(const Color(0xFFE2E8F0)),
      enabledBorder: border(const Color(0xFFE2E8F0)),
      focusedBorder: border(const Color(0xFF16A34A), 1.8),
      errorBorder: border(const Color(0xFFDC2626)),
      focusedErrorBorder: border(const Color(0xFFDC2626), 1.8),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF334155),
      ),
    );
  }
}

class _RememberAndForgotRow extends StatelessWidget {
  const _RememberAndForgotRow({
    required this.rememberMe,
    required this.isLoading,
    required this.onRememberMeChanged,
    required this.onForgotPassword,
  });

  final bool rememberMe;
  final bool isLoading;
  final ValueChanged<bool> onRememberMeChanged;
  final Future<void> Function() onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;

        final rememberWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: rememberMe,
                activeColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: isLoading
                    ? null
                    : (value) => onRememberMeChanged(value ?? true),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Keep me signed in',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
            ),
          ],
        );

        final forgotWidget = TextButton(
          onPressed: isLoading ? null : onForgotPassword,
          child: Text(
            'Forgot password?',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF16A34A),
            ),
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [rememberWidget, const SizedBox(height: 4), forgotWidget],
          );
        }

        return Row(
          children: [rememberWidget, const Spacer(), forgotWidget],
        );
      },
    );
  }
}
