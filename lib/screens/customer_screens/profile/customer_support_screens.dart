import 'package:flutter/material.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:skill_link/screens/shared/skillnova_help_support.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) => SkillNovaHelpSupportScreen(
    audience: SkillNovaHelpAudience.customer,
    safetyBuilder: (_) => const CustomerSafetyScreen(),
  );
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
