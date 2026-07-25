import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const Color _primary = Color(0xFF16A34A);
  static const Color _primaryDark = Color(0xFF0F7A38);
  static const Color _background = Color(0xFFF5F7FB);
  static const Color _surface = Colors.white;
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);

  final TextEditingController _messageController = TextEditingController();

  String _selectedIssue = 'Account issue';
  bool _isSubmitting = false;

  final List<String> _issueTypes = const [
    'Account issue',
    'Wallet or credits',
    'Job or customer issue',
    'Payment issue',
    'App technical issue',
    'Safety concern',
    'Other',
  ];

  final List<_FaqItem> _faqs = const [
    _FaqItem(
      question: 'How do worker credits work?',
      answer:
          'Credits are used when you unlock or accept eligible customer leads. Your current balance and transaction history are available in the Wallet section.',
    ),
    _FaqItem(
      question: 'Why is my job not showing?',
      answer:
          'Make sure the request is assigned to your worker account and has the correct status. Also check your internet connection and refresh the screen.',
    ),
    _FaqItem(
      question: 'How can I report a customer?',
      answer:
          'Open the relevant job or chat and use the report option. You can also select Safety concern on this screen and send the details to support.',
    ),
    _FaqItem(
      question: 'How do I update my worker profile?',
      answer:
          'Open Settings from your worker profile to update your personal information, skill details, availability and account preferences.',
    ),
    _FaqItem(
      question: 'When will I receive a response?',
      answer:
          'Support requests are reviewed as quickly as possible. Include complete details so the team can investigate your issue without delay.',
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        foregroundColor: _textPrimary,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 21),
            ),
          ),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _supportHeroCard(),
                  const SizedBox(height: 22),
                  _quickContactSection(),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    title: 'Common questions',
                    subtitle: 'Find quick answers before contacting support',
                  ),
                  const SizedBox(height: 12),
                  _faqSection(),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    title: 'Send a support request',
                    subtitle: 'Describe your issue and the team will review it',
                  ),
                  const SizedBox(height: 12),
                  _supportForm(),
                  const SizedBox(height: 24),
                  _safetyNotice(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(21, 22, 21, 21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDark, _primary, Color(0xFF3DD56E)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3016A34A),
            blurRadius: 28,
            offset: Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -55,
            right: -48,
            child: Container(
              height: 155,
              width: 155,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SKILLLINK SUPPORT',
                      style: TextStyle(
                        color: Color(0xDFFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 9),
                        SizedBox(width: 6),
                        Text(
                          'Available',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 23),
              const Text(
                'How can we help you?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Get help with your account, jobs, wallet, customers or app-related issues.',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Include complete details for a faster response',
                        style: TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 11.8,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _quickContactSection() {
    return Row(
      children: [
        Expanded(
          child: _contactCard(
            icon: Icons.email_outlined,
            title: 'Email',
            subtitle: 'Send us a message',
            color: const Color(0xFF2563EB),
            background: const Color(0xFFEEF2FF),
            onTap: _sendEmail,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _contactCard(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'WhatsApp',
            subtitle: 'Chat with support',
            color: const Color(0xFF16A34A),
            background: const Color(0xFFEAF8EF),
            onTap: _openWhatsApp,
          ),
        ),
      ],
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 45,
                width: 45,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _faqSection() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(_faqs.length, (index) {
          final faq = _faqs[index];
          return Column(
            children: [
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  iconColor: _primary,
                  collapsedIconColor: _textSecondary,
                  title: Text(
                    faq.question,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq.answer,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index != _faqs.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Divider(height: 1, color: _border),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _supportForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Issue category',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            value: _selectedIssue,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _primary, width: 1.4),
              ),
            ),
            items: _issueTypes
                .map((issue) => DropdownMenuItem(value: issue, child: Text(issue)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedIssue = value);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Describe your issue',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: _messageController,
            minLines: 5,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'Explain what happened and what help you need...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 53,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitSupportRequest,
              icon: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 19),
              label: Text(
                _isSubmitting ? 'Sending...' : 'Submit request',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFEA580C), size: 23),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Never share passwords, OTP codes or sensitive banking details with customers or anyone claiming to be support.',
              style: TextStyle(
                color: Color(0xFFC2410C),
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'muhammadrashid172002@gmail.com',
      queryParameters: {
        'subject': 'SkillLink Worker Support',
        'body': 'Hello SkillLink Support,\n\nIssue Category: $_selectedIssue\n\nPlease describe your issue below:\n\n',
      },
    );
    await _launchUri(uri);
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/923195176014?text=${Uri.encodeComponent('Hello SkillLink Support, I need help with $_selectedIssue.')}',
    );
    await _launchUri(uri);
  }

  Future<void> _launchUri(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this support option.')),
      );
    }
  }

  Future<void> _submitSupportRequest() async {
    final message = _messageController.text.trim();

    if (message.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your issue with more detail.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final uri = Uri(
      scheme: 'mailto',
      path: 'support@skilllink.com',
      queryParameters: {
        'subject': 'SkillLink Support - $_selectedIssue',
        'body': 'Hello SkillLink Support,\n\nIssue Category: $_selectedIssue\n\nIssue Details:\n$message\n\nPlease review this issue and assist me.',
      },
    );

    try {
      await _launchUri(uri);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
