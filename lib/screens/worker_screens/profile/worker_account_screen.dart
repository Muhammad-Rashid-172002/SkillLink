import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';

import 'worker_profile_models.dart';

class WorkerAccountInformationScreen extends StatelessWidget {
  const WorkerAccountInformationScreen({super.key, required this.profile});

  final WorkerProfile profile;

  @override
  Widget build(BuildContext context) {
    final identity = profile.identity;
    final created = profile.createdAt;
    final accountLabel = switch (profile.accountStatus) {
      'blocked' => 'Blocked',
      'suspended' => 'Suspended',
      'inactive' || 'disabled' => 'Inactive',
      _ => 'Active',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Account information')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SettingsSection(
            title: 'Account',
            children: [
              AccountInfoTile(
                label: 'Display name',
                value: profile.name,
                icon: Icons.person_outline,
              ),
              const Divider(height: 1),
              AccountInfoTile(
                label: 'Account role',
                value: profile.role.toLowerCase() == 'worker'
                    ? 'Worker'
                    : profile.role,
                icon: Icons.badge_outlined,
              ),
              const Divider(height: 1),
              AccountInfoTile(
                label: 'Account status',
                value: accountLabel,
                icon: Icons.health_and_safety_outlined,
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
            title: 'Firebase Authentication identity',
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
            'Email and phone come from Firebase Authentication. They cannot be changed as ordinary profile fields; a verified change flow is not available here.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class WorkerDeleteAccountScreen extends StatelessWidget {
  const WorkerDeleteAccountScreen({super.key, this.onContactSupport});

  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.no_accounts_outlined, size: 56, color: colors.error),
          const SizedBox(height: 16),
          Text(
            'Account deletion is handled through support',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'SkillNova does not yet have a complete deletion backend covering Authentication, profile photos, leads, jobs, chats, reviews, verification documents, credits, and retained safety records. This screen does not perform a partial deletion or claim that your account was deleted.',
            textAlign: TextAlign.center,
          ),
          if (onContactSupport != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const ValueKey('worker-delete-contact-support'),
              onPressed: onContactSupport,
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Contact support'),
            ),
          ],
        ],
      ),
    );
  }
}
