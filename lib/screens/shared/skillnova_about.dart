import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:url_launcher/url_launcher.dart';

typedef SkillNovaHelpBuilder = Widget Function(BuildContext context);
typedef SkillNovaUriLauncher = Future<bool> Function(Uri uri);

Future<void> showSkillNovaAboutDialog(
  BuildContext context, {
  required SkillNovaHelpBuilder helpBuilder,
  Future<PackageInfo>? packageInfo,
  bool alreadyOnHelp = false,
  SkillNovaUriLauncher? launchExternal,
}) async {
  void closeThen(VoidCallback action, BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) action();
    });
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => SkillNovaAboutDialog(
      packageInfo: packageInfo,
      websiteUrl: SkillNovaSupportConfig.companyWebsiteUrl,
      onPrivacy: () => closeThen(
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LegalDocumentScreen(
              title: 'Privacy Policy',
              url: SkillNovaSupportConfig.privacyPolicyUrl,
            ),
          ),
        ),
        dialogContext,
      ),
      onTerms: () => closeThen(
        () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const LegalDocumentScreen(
              title: 'Terms of Service',
              url: SkillNovaSupportConfig.termsOfServiceUrl,
            ),
          ),
        ),
        dialogContext,
      ),
      onHelp: () {
        if (alreadyOnHelp) {
          Navigator.of(dialogContext).pop();
          return;
        }
        closeThen(
          () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: helpBuilder)),
          dialogContext,
        );
      },
      onWebsite: SkillNovaSupportConfig.companyWebsiteUrl == null
          ? null
          : () => closeThen(() async {
              final launcher =
                  launchExternal ??
                  (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
              final opened = await launcher(
                SkillNovaSupportConfig.companyWebsiteUrl!,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unable to open the website.')),
                );
              }
            }, dialogContext),
      onLicenses: () => closeThen(
        () => showLicensePage(context: context, applicationName: 'SkillNova'),
        dialogContext,
      ),
      onClose: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

class SkillNovaAboutDialog extends StatelessWidget {
  const SkillNovaAboutDialog({
    super.key,
    this.packageInfo,
    this.websiteUrl,
    required this.onPrivacy,
    required this.onTerms,
    required this.onHelp,
    this.onWebsite,
    required this.onLicenses,
    required this.onClose,
  });

  final Future<PackageInfo>? packageInfo;
  final Uri? websiteUrl;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onHelp;
  final VoidCallback? onWebsite;
  final VoidCallback onLicenses;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      key: const ValueKey('skillnova-about-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: screen.height - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('skillnova-about-scroll'),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: _AboutContent(
                  packageInfo: packageInfo,
                  websiteUrl: websiteUrl,
                  onPrivacy: onPrivacy,
                  onTerms: onTerms,
                  onHelp: onHelp,
                  onWebsite: onWebsite,
                  onLicenses: onLicenses,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('close-about'),
                  onPressed: onClose,
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutSkillNovaScreen extends StatelessWidget {
  const AboutSkillNovaScreen({super.key, this.packageInfo, this.helpBuilder});

  final Future<PackageInfo>? packageInfo;
  final SkillNovaHelpBuilder? helpBuilder;

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('About SkillNova')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          _AboutContent(
            packageInfo: packageInfo,
            websiteUrl: SkillNovaSupportConfig.companyWebsiteUrl,
            onPrivacy: () => open(
              LegalDocumentScreen(
                title: 'Privacy Policy',
                url: SkillNovaSupportConfig.privacyPolicyUrl,
              ),
            ),
            onTerms: () => open(
              const LegalDocumentScreen(
                title: 'Terms of Service',
                url: SkillNovaSupportConfig.termsOfServiceUrl,
              ),
            ),
            onHelp: helpBuilder == null
                ? null
                : () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: helpBuilder!)),
            onWebsite: null,
            onLicenses: () =>
                showLicensePage(context: context, applicationName: 'SkillNova'),
          ),
        ],
      ),
    );
  }
}

class _AboutContent extends StatefulWidget {
  const _AboutContent({
    required this.packageInfo,
    required this.websiteUrl,
    required this.onPrivacy,
    required this.onTerms,
    required this.onHelp,
    required this.onWebsite,
    required this.onLicenses,
  });

  final Future<PackageInfo>? packageInfo;
  final Uri? websiteUrl;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback? onHelp;
  final VoidCallback? onWebsite;
  final VoidCallback onLicenses;

  @override
  State<_AboutContent> createState() => _AboutContentState();
}

class _AboutContentState extends State<_AboutContent> {
  late final Future<PackageInfo> _packageInfo;

  @override
  void initState() {
    super.initState();
    _packageInfo = widget.packageInfo ?? PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SkillNovaRadius.small),
              child: Image.asset(
                'assets/app_icon_512x512(1).png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.handyman_outlined,
                  color: colors.primary,
                  size: 38,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'SkillNova',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Local services, made simple.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'SkillNova connects customers with trusted local professionals for everyday services.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<PackageInfo>(
          future: _packageInfo,
          builder: (context, snapshot) {
            final info = snapshot.data;
            return Container(
              key: const ValueKey('about-version'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
              ),
              child: Text(
                info == null
                    ? 'Loading version…'
                    : 'Version ${info.version} (${info.buildNumber})',
                textAlign: TextAlign.center,
                softWrap: true,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'A product of Korvenza Technologies',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        Divider(color: colors.outlineVariant),
        _AboutActionRow(
          key: const ValueKey('about-privacy'),
          icon: Icons.policy_outlined,
          label: 'Privacy Policy',
          onTap: widget.onPrivacy,
        ),
        _AboutActionRow(
          key: const ValueKey('about-terms'),
          icon: Icons.description_outlined,
          label: 'Terms of Service',
          onTap: widget.onTerms,
        ),
        if (widget.onHelp != null)
          _AboutActionRow(
            key: const ValueKey('about-help'),
            icon: Icons.support_agent_outlined,
            label: 'Help & Support',
            onTap: widget.onHelp!,
          ),
        if (widget.websiteUrl != null && widget.onWebsite != null)
          _AboutActionRow(
            key: const ValueKey('about-website'),
            icon: Icons.language_outlined,
            label: 'Visit Website',
            onTap: widget.onWebsite!,
          ),
        _AboutActionRow(
          key: const ValueKey('about-licenses'),
          icon: Icons.code_rounded,
          label: 'Open Source Licenses',
          onTap: widget.onLicenses,
        ),
        const SizedBox(height: 18),
        Text(
          '© 2026 Korvenza Technologies. All rights reserved.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AboutActionRow extends StatelessWidget {
  const _AboutActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minLeadingWidth: 32,
    leading: Icon(icon, size: 22),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    onTap: onTap,
  );
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.url,
    this.launchExternal,
  });

  final String title;
  final Uri? url;
  final SkillNovaUriLauncher? launchExternal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                url == null
                    ? Icons.description_outlined
                    : Icons.open_in_new_rounded,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                url == null
                    ? '$title is not available'
                    : 'Open the current $title',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                url == null
                    ? 'No approved document or URL is configured in this project. It must be supplied before production.'
                    : 'This document is hosted outside the app and will open in your browser.',
                textAlign: TextAlign.center,
              ),
              if (url != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () async {
                    final launcher =
                        launchExternal ??
                        (uri) => launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                    if (!await launcher(url!) && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to open this document.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open in browser'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
