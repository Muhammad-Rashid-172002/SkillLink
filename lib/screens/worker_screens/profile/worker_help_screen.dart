import 'package:flutter/material.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerHelpScreen extends StatelessWidget {
  const WorkerHelpScreen({super.key});

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
      appBar: AppBar(title: const Text('Worker Help & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'How can we help?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Guidance for worker features currently available in SkillNova.',
          ),
          const SizedBox(height: 24),
          const _WorkerHelpTopic(
            title: 'Leads and lead credits',
            items: [
              (
                'How do leads work?',
                'Eligible workers can browse matching available requests. Open a lead to review its details before accepting.',
              ),
              (
                'Why do I need lead credits?',
                'Accepting a lead currently requires a positive lead-credit balance. Profile readiness separates receiving leads from the credit requirement for accepting one.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _WorkerHelpTopic(
            title: 'Verification and readiness',
            items: [
              (
                'Why is my profile not ready?',
                'Worker role, profile completion, primary skill, approved identity verification, active account status, and accepting-jobs state determine readiness.',
              ),
              (
                'How do I verify?',
                'Open Verification from Profile. The existing Verification Center handles the currently supported submission and review flow.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _WorkerHelpTopic(
            title: 'Jobs, messages, and reviews',
            items: [
              (
                'Where do accepted leads go?',
                'Accepted requests appear in Jobs. Available lifecycle actions depend on the current job status.',
              ),
              (
                'Where are conversations?',
                'Open Messages for request-specific conversations with customers.',
              ),
              (
                'Where are reviews?',
                'Open Reviews from Profile to see the existing ratings and reviews screen.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _WorkerHelpTopic(
            title: 'Account and safety',
            items: [
              (
                'Can I change verified email or phone?',
                'Not in Edit Profile. Those values come from Firebase Authentication and need a verified change flow.',
              ),
              (
                'How do I report suspicious behavior?',
                'Use the problem-report email below and include the request details. For immediate danger, use the police option on the Safety screen.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('worker-email-support'),
            onPressed: () =>
                _email(context, 'SkillNova worker support request'),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email support'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _email(context, 'SkillNova worker problem report'),
            icon: const Icon(Icons.report_problem_outlined),
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

class _WorkerHelpTopic extends StatelessWidget {
  const _WorkerHelpTopic({required this.title, required this.items});

  final String title;
  final List<(String, String)> items;

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
        children: items
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
