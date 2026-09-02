import 'package:flutter/material.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _email(BuildContext context, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SkillNovaSupportConfig.supportEmail,
      queryParameters: {'subject': subject},
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open your email app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'How can we help?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Find guidance for the features available in SkillNova today.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          const _HelpTopic(
            title: 'Booking help',
            children: [
              (
                'Where can I track a request?',
                'Open Bookings from the bottom navigation, then select a request for its current status and available actions.',
              ),
              (
                'How do I contact a professional?',
                'Open Messages or use the conversation attached to an eligible booking.',
              ),
              (
                'Can I cancel a request?',
                'Cancellation is offered only when the request status still permits it. Open the booking details to check.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _HelpTopic(
            title: 'Account help',
            children: [
              (
                'How do I update my profile?',
                'Open Profile and choose Edit profile. Verified email and phone cannot be changed as ordinary profile text.',
              ),
              (
                'Why can’t I change my phone?',
                'Phone number changes require a new Firebase phone verification flow, which is not available in profile settings yet.',
              ),
              (
                'How does the notification switch work?',
                'It controls foreground alerts displayed by SkillNova on this device. It does not unsubscribe your account from server messages.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                _email(context, 'SkillNova customer support request'),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email support'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _email(context, 'SkillNova problem report'),
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('Report a problem'),
          ),
          const SizedBox(height: 12),
          Text(
            SkillNovaSupportConfig.supportEmail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HelpTopic extends StatelessWidget {
  const _HelpTopic({required this.title, required this.children});
  final String title;
  final List<(String, String)> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(title),
        children: children
            .map(
              (item) => ExpansionTile(
                title: Text(item.$1),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Align(alignment: Alignment.centerLeft, child: Text(item.$2)),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class CustomerSafetyScreen extends StatelessWidget {
  const CustomerSafetyScreen({super.key});

  Future<void> _callPolice(BuildContext context) async {
    final uri = Uri(
      scheme: 'tel',
      path: SkillNovaSupportConfig.emergencyNumber,
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dial Police 15 manually.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SafetySupportCard(
            icon: Icons.shield_outlined,
            title: 'Before a service visit',
            body:
                'Keep booking details and communication in SkillNova, confirm the professional shown in your booking, and avoid sharing passwords or OTP codes.',
          ),
          const SafetySupportCard(
            icon: Icons.sos_outlined,
            title: 'SOS during an active booking',
            body:
                'The booking detail and tracking screens provide the existing SOS flow. It sends the active booking and current location to SkillNova safety support.',
          ),
          const SafetySupportCard(
            icon: Icons.report_outlined,
            title: 'Report a problem',
            body:
                'Use Help & Support to email the existing support channel with the booking details. A full dispute workflow is not currently available.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _callPolice(context),
            icon: const Icon(Icons.call_outlined),
            label: const Text('Call Police 15'),
          ),
          const SizedBox(height: 8),
          Text(
            'For immediate danger, contact local emergency services. The profile area does not monitor your location in the background.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
