import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_models.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_support_screens.dart';

export 'package:skill_link/screens/shared/skillnova_about.dart'
    show AboutSkillNovaScreen, LegalDocumentScreen, showSkillNovaAboutDialog;

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
