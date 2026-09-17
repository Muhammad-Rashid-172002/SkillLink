import 'package:flutter/material.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_account_screens.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_settings_screen.dart';
import 'package:skill_link/services/skillnova_preferences.dart';

import 'worker_account_screen.dart';
import 'worker_help_screen.dart';
import 'worker_privacy_screen.dart';
import 'worker_profile_models.dart';
import 'worker_profile_repository.dart';
import 'worker_safety_screen.dart';

class WorkerSettingsScreen extends StatefulWidget {
  const WorkerSettingsScreen({
    super.key,
    required this.profile,
    this.preferences,
    this.repository,
    this.onLoggedOut,
  });

  final WorkerProfile profile;
  final SkillNovaPreferencesController? preferences;
  final WorkerProfileRepository? repository;
  final VoidCallback? onLoggedOut;

  @override
  State<WorkerSettingsScreen> createState() => _WorkerSettingsScreenState();
}

class _WorkerSettingsScreenState extends State<WorkerSettingsScreen> {
  late final SkillNovaPreferencesController _preferences;
  late final WorkerProfileRepository _repository;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? skillNovaPreferences;
    _repository = widget.repository ?? FirebaseWorkerProfileRepository();
  }

  void _open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _selectTheme(ThemeMode mode) async {
    final saved = identical(_preferences, skillNovaPreferences)
        ? await SkillNovaThemeController.setMode(mode)
        : await _preferences.setThemeMode(mode);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme preference could not be saved.')),
      );
    }
  }

  Future<void> _setForegroundAlerts(bool value) async {
    if (!await _preferences.setLocalNotificationsEnabled(value) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification preference could not be saved.'),
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out of SkillNova?'),
        content: const Text(
          'Your account data will remain safe. You will need to sign in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await _repository.signOut();
      if (!mounted) return;
      final callback = widget.onLoggedOut;
      if (callback != null) {
        setState(() => _loggingOut = false);
        callback();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Worker Settings')),
      body: AnimatedBuilder(
        animation: _preferences,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            SettingsSection(
              title: 'Appearance',
              children: [
                Padding(
                  padding: const EdgeInsets.all(SkillNovaSpacing.md),
                  child: ThemeSelector(
                    value: _preferences.themeMode,
                    onChanged: _selectTheme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Notifications',
              children: [
                SwitchListTile(
                  key: const ValueKey('worker-foreground-alert-switch'),
                  value: _preferences.localNotificationsEnabled,
                  onChanged: _setForegroundAlerts,
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Foreground alerts on this device'),
                  subtitle: const Text(
                    'Controls alerts SkillNova displays while this app is open. Server and system notifications may still arrive.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Privacy & account',
              children: [
                ProfileMenuTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account information',
                  subtitle: 'Verified identity and account status',
                  onTap: () => _open(
                    WorkerAccountInformationScreen(profile: widget.profile),
                  ),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  subtitle: 'What is public and what remains private',
                  onTap: () => _open(const WorkerPrivacyScreen()),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.no_accounts_outlined,
                  title: 'Delete account',
                  subtitle: 'Review the current support-managed process',
                  danger: true,
                  onTap: () => _open(
                    WorkerDeleteAccountScreen(
                      onContactSupport: () => _open(const WorkerHelpScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Support & safety',
              children: [
                ProfileMenuTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Help & Support',
                  subtitle: 'Worker guidance and the support email channel',
                  onTap: () => _open(const WorkerHelpScreen()),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Safety',
                  subtitle: 'SOS, on-the-way sharing, and emergency guidance',
                  onTap: () => _open(
                    WorkerSafetyScreen(
                      onReport: () => _open(const WorkerHelpScreen()),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Document availability',
                  onTap: () => _open(
                    const LegalDocumentScreen(
                      title: 'Terms of Service',
                      url: SkillNovaSupportConfig.termsOfServiceUrl,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.policy_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Open the currently configured page',
                  onTap: () => _open(
                    LegalDocumentScreen(
                      title: 'Privacy Policy',
                      url: SkillNovaSupportConfig.privacyPolicyUrl,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'About',
              children: [
                ProfileMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: 'SkillNova',
                  subtitle: 'About and application version',
                  onTap: () => showSkillNovaAboutDialog(
                    context,
                    helpBuilder: (_) => const WorkerHelpScreen(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const ValueKey('worker-settings-logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _loggingOut ? null : _confirmLogout,
              icon: _loggingOut
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(_loggingOut ? 'Logging out…' : 'Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
