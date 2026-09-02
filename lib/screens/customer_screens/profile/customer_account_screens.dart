import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_models.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_support_screens.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerAccountInformationScreen extends StatelessWidget {
  const CustomerAccountInformationScreen({super.key, required this.profile});
  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final identity = profile.identity;
    final created = profile.createdAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Account information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: 'Profile',
            children: [
              AccountInfoTile(
                label: 'Display name',
                value: profile.name,
                icon: Icons.person_outline,
              ),
              const Divider(height: 1),
              const AccountInfoTile(
                label: 'Account role',
                value: 'Customer',
                icon: Icons.badge_outlined,
              ),
              if (created != null) ...[
                const Divider(height: 1),
                AccountInfoTile(
                  label: 'Member since',
                  value: DateFormat.yMMMMd().format(created),
                  icon: Icons.calendar_today_outlined,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SettingsSection(
            title: 'Verified identity',
            children: [
              AccountInfoTile(
                label: identity.emailVerified
                    ? 'Verified email'
                    : 'Account email (not verified)',
                value: identity.email.isEmpty ? 'Not linked' : identity.email,
                icon: Icons.email_outlined,
              ),
              const Divider(height: 1),
              AccountInfoTile(
                label: identity.phoneVerified ? 'Verified phone' : 'Phone',
                value: identity.phoneVerified ? identity.phone : 'Not linked',
                icon: Icons.phone_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Email and phone come from Firebase Authentication. They cannot be edited as ordinary profile fields.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class CustomerPrivacyScreen extends StatelessWidget {
  const CustomerPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [
          SafetySupportCard(
            icon: Icons.person_outline,
            title: 'Profile information',
            body:
                'Your customer profile supports a display name, photo, city, service area, address, and bio. No profile visibility toggle exists today.',
          ),
          SafetySupportCard(
            icon: Icons.location_on_outlined,
            title: 'Location usage',
            body:
                'Location is used for nearby professional discovery and can be attached to the existing SOS flow during an active booking. This page does not enable background tracking.',
          ),
          SafetySupportCard(
            icon: Icons.chat_bubble_outline,
            title: 'Message privacy',
            body:
                'Messages are available to the participants of the conversation. Do not share passwords, OTP codes, or sensitive financial information.',
          ),
          SafetySupportCard(
            icon: Icons.reviews_outlined,
            title: 'Public review identity',
            body:
                'Worker reviews may show your display name, profile image, rating, review text, and verified-booking context. They do not show your phone, email, or exact address.',
          ),
        ],
      ),
    );
  }
}

class DeleteAccountSafetyScreen extends StatelessWidget {
  const DeleteAccountSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(Icons.no_accounts_outlined, size: 54, color: colors.error),
          const SizedBox(height: 16),
          Text(
            'Account deletion is not available yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'SkillNova does not currently have a complete deletion backend for Authentication, profile photos, bookings, chats, reviews, and retained safety records. To avoid leaving orphaned data, this screen does not perform a partial deletion.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const HelpSupportScreen(),
              ),
            ),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Contact support'),
          ),
        ],
      ),
    );
  }
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.url,
  });
  final String title;
  final Uri? url;

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
                    if (!await launchUrl(
                          url!,
                          mode: LaunchMode.externalApplication,
                        ) &&
                        context.mounted) {
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

class AboutSkillNovaScreen extends StatelessWidget {
  const AboutSkillNovaScreen({super.key, this.packageInfo});
  final Future<PackageInfo>? packageInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About SkillNova')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.handyman_outlined,
            size: 62,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'SkillNova',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'A service marketplace connecting customers with eligible professionals.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FutureBuilder<PackageInfo>(
            future: packageInfo ?? PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return Text(
                info == null
                    ? 'Loading version…'
                    : 'Version ${info.version} (${info.buildNumber})',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              );
            },
          ),
        ],
      ),
    );
  }
}
