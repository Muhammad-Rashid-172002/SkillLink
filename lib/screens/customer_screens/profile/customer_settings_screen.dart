import 'package:flutter/material.dart';
import 'package:skill_link/screens/shared/security_settings_section.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            SettingsSection(
              title: 'Account',
              children: [
                ProfileMenuTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account information',
                  subtitle: 'Name, email and verified phone',
                  onTap: () => _open(
                    CustomerAccountInformationScreen(profile: widget.profile),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SecuritySettingsSection(),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Notifications',
              children: [
                SwitchListTile(
                  key: const Key('local-notification-switch'),
                  value: _preferences.localNotificationsEnabled,
                  onChanged: _setNotifications,
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('In-app alerts'),
                  subtitle: const Text(
                    'Show alerts while SkillNova is open on this device.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'Preferences',
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
              title: 'Privacy',
              children: [
                ProfileMenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Your data',
                  subtitle: 'How SkillNova uses and protects your data',
                  onTap: () => _open(const CustomerPrivacyScreen()),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.policy_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we collect and use your information',
                  onTap: () => _open(
                    LegalDocumentScreen(
                      title: 'Privacy Policy',
                      url: SkillNovaSupportConfig.privacyPolicyUrl,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'The rules for using SkillNova',
                  onTap: () => _open(
                    const LegalDocumentScreen(
                      title: 'Terms of Service',
                      url: SkillNovaSupportConfig.termsOfServiceUrl,
                    ),
                  ),
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
                  subtitle: 'Answers to common questions and how to reach us',
                  onTap: () => _open(const HelpSupportScreen()),
                ),
                const Divider(height: 1),
                ProfileMenuTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Safety',
                  subtitle: 'Staying safe and what to do in an emergency',
                  onTap: () => _open(const CustomerSafetyScreen()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SettingsSection(
              title: 'About',
              children: [
                ProfileMenuTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About SkillNova',
                  subtitle: 'Version and legal information',
                  onTap: () => showSkillNovaAboutDialog(
                    context,
                    helpBuilder: (_) => const HelpSupportScreen(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                key: const Key('logout-button'),
                onPressed: _loggingOut ? null : _confirmLogout,
                icon: _loggingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(_loggingOut ? 'Logging out…' : 'Log out'),
              ),
            ),
            const SizedBox(height: 28),
            // Permanent, destructive actions live apart from everyday ones.
            SettingsSection(
              title: 'Danger zone',
              children: [
                ProfileMenuTile(
                  icon: Icons.no_accounts_outlined,
                  title: 'Delete account',
                  subtitle: 'Permanently close your SkillNova account',
                  danger: true,
                  onTap: () => _open(const DeleteAccountSafetyScreen()),
                ),
              ],
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
