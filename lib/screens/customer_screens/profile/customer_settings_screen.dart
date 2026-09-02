import 'package:flutter/material.dart';
import 'package:skill_link/config/skillnova_support_config.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_account_screens.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_components.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_models.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_repository.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_support_screens.dart';
import 'package:skill_link/services/skillnova_preferences.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({
    super.key,
    required this.profile,
    this.preferences,
    this.repository,
    this.onLoggedOut,
  });

  final CustomerProfile profile;
  final SkillNovaPreferencesController? preferences;
  final CustomerProfileRepository? repository;
  final VoidCallback? onLoggedOut;

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  late final SkillNovaPreferencesController _preferences;
  late final CustomerProfileRepository _repository;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferences ?? skillNovaPreferences;
    _repository = widget.repository ?? FirebaseCustomerProfileRepository();
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

  Future<void> _setNotifications(bool value) async {
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
      if (widget.onLoggedOut case final callback?) {
        setState(() => _loggingOut = false);
        callback();
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const RoleSelectionScreen()),
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout failed. Please try again.')),
        );
        setState(() => _loggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
                  key: const Key('local-notification-switch'),
                  value: _preferences.localNotificationsEnabled,
                  onChanged: _setNotifications,
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
                  subtitle: 'Verified identity and account details',
                  onTap: () => _open(
                    CustomerAccountInformationScreen(profile: widget.profile),
                  ),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  subtitle: 'How current app features use your information',
                  onTap: () => _open(const CustomerPrivacyScreen()),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.no_accounts_outlined,
                  title: 'Delete account',
                  subtitle: 'Review the current safe availability state',
                  danger: true,
                  onTap: () => _open(const DeleteAccountSafetyScreen()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Support',
              children: [
                ProfileMenuTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Help & Support',
                  subtitle: 'Guidance and the existing email channel',
                  onTap: () => _open(const HelpSupportScreen()),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Safety',
                  subtitle: 'Safety guidance and emergency information',
                  onTap: () => _open(const CustomerSafetyScreen()),
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
                  onTap: () => _open(const AboutSkillNovaScreen()),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('logout-button'),
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

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const choices = <(ThemeMode, IconData, String)>[
      (ThemeMode.system, Icons.brightness_auto_outlined, 'System'),
      (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: choices
              .map(
                (choice) => ChoiceChip(
                  key: Key('theme-${choice.$1.name}'),
                  selected: value == choice.$1,
                  onSelected: (_) => onChanged(choice.$1),
                  avatar: Icon(choice.$2, size: 18),
                  label: Text(choice.$3),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
