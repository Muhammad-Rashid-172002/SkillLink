import 'package:flutter/material.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerSafetyScreen extends StatelessWidget {
  const WorkerSafetyScreen({super.key, this.onReport});

  final VoidCallback? onReport;

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
      appBar: AppBar(title: const Text('Worker Safety')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SafetySupportCard(
            icon: Icons.sos_outlined,
            title: 'SOS during an active assigned job',
            body:
                'The existing Step 8 job detail flow provides SOS for an assigned active request and records the supported request and location context for SkillNova safety support.',
          ),
          const SafetySupportCard(
            icon: Icons.route_outlined,
            title: 'On-the-way location sharing',
            body:
                'Location sharing starts only through the supported on-the-way job flow and is foreground-only. SkillNova does not continuously monitor your location in the background.',
          ),
          SafetySupportCard(
            icon: Icons.report_outlined,
            title: 'Report suspicious behavior',
            body:
                'Use Help & Support to email the current support channel and include the request details. A full in-app moderation or dispute workflow is not available.',
            onTap: onReport,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('worker-call-police'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _callPolice(context),
            icon: const Icon(Icons.call_outlined),
            label: const Text('Call Police 15'),
          ),
          const SizedBox(height: 8),
          Text(
            'For immediate danger, contact local emergency services. SkillNova does not automatically contact police.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
