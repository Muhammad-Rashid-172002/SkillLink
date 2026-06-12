import 'package:flutter/material.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_setup_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_setup.dart';

class AuthScreen extends StatefulWidget {
  final String role; // customer OR worker

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = false;
  bool isEmail = true;
  bool hidePassword = true;

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.role == "customer";
    final primaryColor = isCustomer
        ? const Color(0xFF2563EB)
        : const Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(context, primaryColor),
              const SizedBox(height: 26),
              _heroSection(isCustomer, primaryColor),
              const SizedBox(height: 26),
              _authCard(primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, Color primaryColor) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(.10),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            widget.role.toUpperCase(),
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroSection(bool isCustomer, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCustomer ? Icons.person_search_rounded : Icons.handyman_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLogin ? "Welcome Back" : "Create Account",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isCustomer
                      ? "Find trusted workers near you"
                      : "Get jobs and grow your skills",
                  style: TextStyle(
                    color: Colors.white.withOpacity(.86),
                    fontSize: 14.5,
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

  Widget _authCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.07),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          _mainToggle(primaryColor),
          const SizedBox(height: 24),
          _loginTypeTabs(primaryColor),
          const SizedBox(height: 26),

          if (!isLogin) ...[
            _field(
              label: "Full Name",
              hint: "Ahmad Khan",
              icon: Icons.person_outline_rounded,
              primaryColor: primaryColor,
            ),
            const SizedBox(height: 18),
          ],

          _field(
            label: isEmail ? "Email Address" : "Phone Number",
            hint: isEmail ? "you@example.com" : "+92 300 0000000",
            icon: isEmail ? Icons.email_outlined : Icons.phone_outlined,
            primaryColor: primaryColor,
          ),

          const SizedBox(height: 18),

          _passwordField(primaryColor),

          if (isLogin) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          _primaryButton(primaryColor),
          const SizedBox(height: 24),
          _divider(),
          const SizedBox(height: 22),
          _googleButton(),
          const SizedBox(height: 24),
          _bottomText(primaryColor),
        ],
      ),
    );
  }

  Widget _mainToggle(Color primaryColor) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _toggleItem("Log In", isLogin, primaryColor, () {
            setState(() => isLogin = true);
          }),
          _toggleItem("Sign Up", !isLogin, primaryColor, () {
            setState(() => isLogin = false);
          }),
        ],
      ),
    );
  }

  Widget _toggleItem(
    String text,
    bool active,
    Color primaryColor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.07),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Text(
            text,
            style: TextStyle(
              color: active ? primaryColor : const Color(0xFF64748B),
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginTypeTabs(Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: _smallTab(
            title: "Email",
            icon: Icons.email_outlined,
            active: isEmail,
            primaryColor: primaryColor,
            onTap: () => setState(() => isEmail = true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _smallTab(
            title: "Phone",
            icon: Icons.phone_outlined,
            active: !isEmail,
            primaryColor: primaryColor,
            onTap: () => setState(() => isEmail = false),
          ),
        ),
      ],
    );
  }

  Widget _smallTab({
    required String title,
    required IconData icon,
    required bool active,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? primaryColor.withOpacity(.09) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: active ? primaryColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: active ? primaryColor : const Color(0xFF64748B),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          decoration: _inputDecoration(
            hint: hint,
            icon: icon,
            primaryColor: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _passwordField(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("Password"),
        TextField(
          obscureText: hidePassword,
          decoration:
              _inputDecoration(
                hint: "••••••••",
                icon: Icons.lock_outline_rounded,
                primaryColor: primaryColor,
              ).copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => hidePassword = !hidePassword),
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color primaryColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: primaryColor, width: 1.8),
      ),
    );
  }

  Widget _primaryButton(Color primaryColor) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: ElevatedButton(
       onPressed: () {
  if (widget.role == "worker") {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const WorkerProfileSetupScreen(),
      ),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerProfileSetupScreen(),
      ),
    );
  }
},
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          isLogin ? "Log In" : "Create Account",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            "or continue with",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE2E8F0))),
      ],
    );
  }

  Widget _googleButton() {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text(
          "G  Continue with Google",
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _bottomText(Color primaryColor) {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => isLogin = !isLogin),
        child: RichText(
          text: TextSpan(
            text: isLogin
                ? "Don’t have an account? "
                : "Already have an account? ",
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(
                text: isLogin ? "Sign Up" : "Log In",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
