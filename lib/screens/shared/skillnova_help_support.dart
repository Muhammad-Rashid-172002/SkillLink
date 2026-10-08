import 'package:flutter/material.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/shared/skillnova_about.dart';
import 'package:url_launcher/url_launcher.dart';

enum SkillNovaHelpAudience { customer, worker }

class SkillNovaHelpSupportScreen extends StatelessWidget {
  const SkillNovaHelpSupportScreen({
    super.key,
    required this.audience,
    required this.safetyBuilder,
    this.launchExternal,
    this.packageInfo,
  });

  final SkillNovaHelpAudience audience;
  final WidgetBuilder safetyBuilder;
  final SkillNovaUriLauncher? launchExternal;
  final Future<PackageInfo>? packageInfo;

  bool get _isWorker => audience == SkillNovaHelpAudience.worker;

  List<_HelpCategoryData> get _categories => _isWorker
      ? const [
          _HelpCategoryData(
            icon: Icons.workspace_premium_outlined,
            title: 'Leads & Lead Credits',
            body:
                'Lead credits are used when accepting eligible service leads. They are not earnings or wallet balance.',
          ),
          _HelpCategoryData(
            icon: Icons.verified_user_outlined,
            title: 'Verification',
            body:
                'Complete identity verification to become eligible for jobs where verification is required.',
          ),
          _HelpCategoryData(
            icon: Icons.work_outline_rounded,
            title: 'Accepting Jobs / Readiness',
            body:
                'You can control whether you are accepting new jobs when your account is eligible.',
          ),
          _HelpCategoryData(
            icon: Icons.assignment_outlined,
            title: 'Jobs & Job Status',
            body:
                'Accepted requests appear in Jobs. The actions available there depend on the current job status.',
          ),
          _HelpCategoryData(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Messages',
            body:
                'Use SkillNova Messages to communicate with customers about active service requests.',
          ),
          _HelpCategoryData(
            icon: Icons.reviews_outlined,
            title: 'Reviews',
            body:
                'Open Reviews from your profile to view ratings and feedback currently associated with your work.',
          ),
          _HelpCategoryData(
            icon: Icons.manage_accounts_outlined,
            title: 'Account & Profile',
            body:
                'Edit supported professional details from Profile. Verified email and phone require separate verified account flows.',
          ),
          _HelpCategoryData(
            icon: Icons.health_and_safety_outlined,
            title: 'Safety',
            body:
                'Use the available safety tools during legitimate assigned jobs and report suspicious behavior.',
          ),
        ]
      : const [
          _HelpCategoryData(
            icon: Icons.search_rounded,
            title: 'Finding Professionals',
            body:
                'Use Home and Explore to browse available professionals by the discovery options currently shown in the app.',
          ),
          _HelpCategoryData(
            icon: Icons.calendar_month_outlined,
            title: 'Booking / Requests',
            body:
                'Open Bookings from the bottom navigation to view a request, its current status, and available actions.',
          ),
          _HelpCategoryData(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Messages',
            body:
                'Use SkillNova Messages for conversations connected to eligible service requests.',
          ),
          _HelpCategoryData(
            icon: Icons.reviews_outlined,
            title: 'Reviews',
            body:
                'Reviews are available through the supported completed-booking flow and may appear on professional profiles.',
          ),
          _HelpCategoryData(
            icon: Icons.manage_accounts_outlined,
            title: 'Account & Profile',
            body:
                'Edit supported details from Profile. Verified email and phone require separate verified account flows.',
          ),
          _HelpCategoryData(
            icon: Icons.health_and_safety_outlined,
            title: 'Safety',
            body:
                'Keep request details and communication in SkillNova, use available safety tools during active bookings, and report suspicious behavior.',
          ),
        ];

  Future<void> _email(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SkillNovaSupportConfig.supportEmail,
      queryParameters: const {'subject': 'SkillNova Support Request'},
    );
    final launcher =
        launchExternal ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!await launcher(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open your email app.')),
      );
    }
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        key: const ValueKey('help-support-content'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Find answers or get help with your SkillNova account.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          _QuickSupportCard(onEmail: () => _email(context)),
          const SizedBox(height: 26),
          Semantics(
            header: true,
            child: Text(
              _isWorker ? 'Worker help topics' : 'Customer help topics',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 10),
          // One grouped card of questions rather than a stack of cards.
          Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SkillNovaRadius.large),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _categories.length; i++) ...[
                  _HelpCategory(data: _categories[i]),
                  if (i != _categories.length - 1)
                    const Divider(height: 1, indent: 64),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text('More help', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 10),
          _SupportActions(
            onEmail: () => _email(context),
            onPrivacy: () => _open(
              context,
              LegalDocumentScreen(
                title: 'Privacy Policy',
                url: SkillNovaSupportConfig.privacyPolicyUrl,
                launchExternal: launchExternal,
              ),
            ),
            onTerms: () => _open(
              context,
              const LegalDocumentScreen(
                title: 'Terms of Service',
                url: SkillNovaSupportConfig.termsOfServiceUrl,
              ),
            ),
            onSafety: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: safetyBuilder)),
            onAbout: () => showSkillNovaAboutDialog(
              context,
              packageInfo: packageInfo,
              alreadyOnHelp: true,
              launchExternal: launchExternal,
              helpBuilder: (_) => SkillNovaHelpSupportScreen(
                audience: audience,
                safetyBuilder: safetyBuilder,
                launchExternal: launchExternal,
                packageInfo: packageInfo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickSupportCard extends StatelessWidget {
  const _QuickSupportCard({required this.onEmail});

  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(SkillNovaRadius.small),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact SkillNova Support',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      SkillNovaSupportConfig.supportEmail,
                      key: const ValueKey('support-email'),
                      softWrap: true,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('email-support'),
            onPressed: onEmail,
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email Support'),
          ),
        ],
      ),
    );
  }
}

class _HelpCategoryData {
  const _HelpCategoryData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _HelpCategory extends StatelessWidget {
  const _HelpCategory({required this.data});

  final _HelpCategoryData data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Theme(
      // No divider lines inside the expanded tile; the group draws them.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: IconTile(icon: data.icon, size: 36),
        title: Text(data.title, style: Theme.of(context).textTheme.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportActions extends StatelessWidget {
  const _SupportActions({
    required this.onEmail,
    required this.onPrivacy,
    required this.onTerms,
    required this.onSafety,
    required this.onAbout,
  });

  final VoidCallback onEmail;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onSafety;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actions = [
      (Icons.email_outlined, 'Email Support', onEmail),
      (Icons.policy_outlined, 'Privacy Policy', onPrivacy),
      (Icons.description_outlined, 'Terms of Service', onTerms),
      (Icons.health_and_safety_outlined, 'Safety Information', onSafety),
      (Icons.info_outline_rounded, 'About SkillNova', onAbout),
    ];
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SkillNovaRadius.large),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            ListTile(
              key: ValueKey('support-action-$index'),
              leading: Icon(actions[index].$1, size: 22),
              title: Text(actions[index].$2),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: actions[index].$3,
            ),
            if (index != actions.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
