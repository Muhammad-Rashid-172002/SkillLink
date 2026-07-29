import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const Color _background = Color(0xFFF4F7FB);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _success = Color(0xFF16A34A);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _cyan = Color(0xFF0891B2);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  static const String _supportEmail =
      'muhammadrashid172002@gmail.com';

  Future<void> _sendEmail(BuildContext context) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'SkillNova Support Request',
        'body': '''
Hello SkillNova Support Team,

I need help with the following issue:

Issue Details:
--------------------------------------------------

--------------------------------------------------

Account Information:
- Name:
- Registered Email:
- User Type: Customer / Worker

Device Information:
- Device Model:
- Android/iOS Version:
- App Version:

Thank you.
''',
      },
    );

    await _launchUri(
      context,
      uri,
      errorMessage: 'Unable to open your email app.',
    );
  }

  Future<void> _reportIssue(BuildContext context) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'SkillNova Bug Report',
        'body': '''
Hello SkillNova Team,

I found an issue in the app.

Issue Title:
--------------------------------------------------

Steps to Reproduce:
1.
2.
3.

Expected Result:
--------------------------------------------------

Actual Result:
--------------------------------------------------

Device Information:
- Device Model:
- Android/iOS Version:
- App Version:

Screenshot attached: Yes / No

Thank you.
''',
      },
    );

    await _launchUri(
      context,
      uri,
      errorMessage: 'Unable to open your email app.',
    );
  }

  Future<void> _launchUri(
    BuildContext context,
    Uri uri, {
    required String errorMessage,
  }) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!context.mounted) return;

        _showSnackBar(
          context,
          message: errorMessage,
          isError: true,
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      _showSnackBar(
        context,
        message: errorMessage,
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 18),
                    _buildSectionTitle(
                      icon: Icons.support_agent_rounded,
                      title: 'Contact Support',
                      subtitle:
                          'Choose the best way to get assistance',
                    ),
                    const SizedBox(height: 13),
                    _buildContactCards(context),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      icon: Icons.quiz_outlined,
                      title: 'Frequently Asked Questions',
                      subtitle:
                          'Quick answers to common SkillNova questions',
                    ),
                    const SizedBox(height: 13),
                    _buildFaqSection(),
                    const SizedBox(height: 20),
                    _buildSectionTitle(
                      icon: Icons.info_outline_rounded,
                      title: 'Support Information',
                      subtitle:
                          'Important details about our support service',
                    ),
                    const SizedBox(height: 13),
                    _buildSupportInformationCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: _textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.45,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'We are here to help you',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: _primary.withOpacity(.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.headset_mic_outlined,
              color: _primary,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _primaryDark],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.23),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -68,
            right: -48,
            child: Container(
              height: 165,
              width: 165,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -78,
            left: -58,
            child: Container(
              height: 175,
              width: 175,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                height: 78,
                width: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(.17),
                  ),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 39,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How can we help?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.25,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Find quick answers or contact our support team for help with your SkillNova account.',
                      style: TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 10,
                        height: 1.55,
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

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: _primary.withOpacity(.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: _primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactCards(BuildContext context) {
    return Column(
      children: [
        _supportActionCard(
          icon: Icons.email_outlined,
          iconColor: _primary,
          title: 'Email Support',
          subtitle:
              'Send us your question and receive a detailed response.',
          actionText: 'Send Email',
          onTap: () => _sendEmail(context),
        ),
        const SizedBox(height: 12),
        _supportActionCard(
          icon: Icons.bug_report_outlined,
          iconColor: _danger,
          title: 'Report a Problem',
          subtitle:
              'Tell us about a bug, error or unexpected app behavior.',
          actionText: 'Report Issue',
          onTap: () => _reportIssue(context),
        ),
        const SizedBox(height: 12),
        _supportActionCard(
          icon: Icons.forum_outlined,
          iconColor: _purple,
          title: 'Community Guidance',
          subtitle:
              'Check FAQs below for help with jobs, workers and payments.',
          actionText: 'View FAQs',
          onTap: () {
            _showSnackBar(
              context,
              message:
                  'Scroll down to explore frequently asked questions.',
            );
          },
        ),
      ],
    );
  }

  Widget _supportActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(.09),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 9.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  actionText,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          _FaqTile(
            icon: Icons.person_search_outlined,
            iconColor: _primary,
            question: 'How do I hire a worker?',
            answer:
                'Open a worker profile, review their skills and ratings, then tap the Hire Worker button to send a direct service request.',
          ),
          Divider(height: 1, color: _border),
          _FaqTile(
            icon: Icons.assignment_outlined,
            iconColor: _purple,
            question: 'Where can I track my request?',
            answer:
                'Open My Requests from your customer profile. You can view pending, accepted, in-progress, completed and cancelled requests.',
          ),
          Divider(height: 1, color: _border),
          _FaqTile(
            icon: Icons.cancel_outlined,
            iconColor: _danger,
            question: 'Can I cancel a service request?',
            answer:
                'You can cancel a request while its status is Pending. Accepted or in-progress requests cannot be cancelled directly from the request list.',
          ),
          Divider(height: 1, color: _border),
          _FaqTile(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: _cyan,
            question: 'How can I contact a worker?',
            answer:
                'Use the Call or Chat option available on the worker profile. Contact details must be available in the worker account.',
          ),
          Divider(height: 1, color: _border),
          _FaqTile(
            icon: Icons.star_outline_rounded,
            iconColor: _warning,
            question: 'How do I review a worker?',
            answer:
                'After the job is completed, open the completed request and submit your rating and feedback for the worker.',
          ),
          Divider(height: 1, color: _border),
          _FaqTile(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: _success,
            question: 'How do worker credits work?',
            answer:
                'Workers use credits to access or accept service leads. Credit packages can be purchased from the worker wallet screen.',
          ),
        ],
      ),
    );
  }

  Widget _buildSupportInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _informationRow(
            icon: Icons.schedule_outlined,
            iconColor: _warning,
            title: 'Response Time',
            value: 'Usually within 24–48 hours',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: _border),
          ),
          _informationRow(
            icon: Icons.email_outlined,
            iconColor: _primary,
            title: 'Support Email',
            value: _supportEmail,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: _border),
          ),
          _informationRow(
            icon: Icons.language_outlined,
            iconColor: _cyan,
            title: 'Supported Languages',
            value: 'English and Urdu',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _success.withOpacity(.07),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: _success.withOpacity(.15),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: _success,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Never share your password, OTP or sensitive payment information with anyone claiming to be support staff.',
                    style: TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 9.5,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(.09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _textPrimary,
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: _border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x060F172A),
          blurRadius: 17,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
          content: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isError
                    ? const [
                        Color(0xFFDC2626),
                        Color(0xFFEF4444),
                      ]
                    : const [
                        Color(0xFF16A34A),
                        Color(0xFF14B8A6),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      (isError ? _danger : _success).withOpacity(.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 37,
                  width: 37,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError
                        ? Icons.error_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
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

class _FaqTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String question;
  final String answer;

  const _FaqTile({
    required this.icon,
    required this.iconColor,
    required this.question,
    required this.answer,
  });

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _isExpanded = false;

  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          horizontal: 3,
          vertical: 14,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(.09),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? .5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    height: 31,
                    width: 31,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _textSecondary,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        53,
                        11,
                        8,
                        2,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.answer,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 9.5,
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
