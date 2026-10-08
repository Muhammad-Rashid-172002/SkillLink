import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilllink_admin/theme/admin_design.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/settings_management_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final SettingsManagementService _service = SettingsManagementService();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _appNameController;
  late final TextEditingController _supportEmailController;
  late final TextEditingController _supportPhoneController;
  late final TextEditingController _privacyController;
  late final TextEditingController _termsController;
  late final TextEditingController _defaultCreditsController;
  late final TextEditingController _creditsPerLeadController;
  late final TextEditingController _lowCreditsController;

  AdminSettings? _settings;
  bool _initialized = false;
  bool _saving = false;

  String _currency = 'PKR';
  String _timeZone = 'Asia/Karachi';
  String _dateFormat = 'dd MMM yyyy';

  bool _autoCreditDeduction = true;
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _newJobAlerts = true;
  bool _newUserAlerts = true;
  bool _complaintAlerts = true;
  bool _maintenanceMode = false;
  bool _twoFactorAuthentication = false;
  bool _darkMode = false;
  bool _compactSidebar = false;

  int _sessionTimeoutMinutes = 30;

  @override
  void initState() {
    super.initState();

    _appNameController = TextEditingController();
    _supportEmailController = TextEditingController();
    _supportPhoneController = TextEditingController();
    _privacyController = TextEditingController();
    _termsController = TextEditingController();
    _defaultCreditsController = TextEditingController();
    _creditsPerLeadController = TextEditingController();
    _lowCreditsController = TextEditingController();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _privacyController.dispose();
    _termsController.dispose();
    _defaultCreditsController.dispose();
    _creditsPerLeadController.dispose();
    _lowCreditsController.dispose();
    super.dispose();
  }

  void _loadIntoForm(AdminSettings settings) {
    if (_initialized) return;

    _settings = settings;
    _appNameController.text = settings.appName;
    _supportEmailController.text = settings.supportEmail;
    _supportPhoneController.text = settings.supportPhone;
    _privacyController.text = settings.privacyPolicyUrl;
    _termsController.text = settings.termsUrl;
    _defaultCreditsController.text = settings.defaultWorkerCredits.toString();
    _creditsPerLeadController.text = settings.creditsPerLead.toString();
    _lowCreditsController.text = settings.lowCreditWarning.toString();

    _currency = settings.currency;
    _timeZone = settings.timeZone;
    _dateFormat = settings.dateFormat;

    _autoCreditDeduction = settings.autoCreditDeduction;
    _pushNotifications = settings.pushNotifications;
    _emailNotifications = settings.emailNotifications;
    _newJobAlerts = settings.newJobAlerts;
    _newUserAlerts = settings.newUserAlerts;
    _complaintAlerts = settings.complaintAlerts;
    _maintenanceMode = settings.maintenanceMode;
    _twoFactorAuthentication = settings.twoFactorAuthentication;
    _darkMode = settings.darkMode;
    _compactSidebar = settings.compactSidebar;
    _sessionTimeoutMinutes = settings.sessionTimeoutMinutes;

    _initialized = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final current = _settings ?? AdminSettings.defaults();

    final updated = current.copyWith(
      appName: _appNameController.text.trim(),
      supportEmail: _supportEmailController.text.trim(),
      supportPhone: _supportPhoneController.text.trim(),
      privacyPolicyUrl: _privacyController.text.trim(),
      termsUrl: _termsController.text.trim(),
      currency: _currency,
      timeZone: _timeZone,
      dateFormat: _dateFormat,
      defaultWorkerCredits:
          int.tryParse(_defaultCreditsController.text.trim()) ?? 0,
      creditsPerLead: int.tryParse(_creditsPerLeadController.text.trim()) ?? 0,
      lowCreditWarning: int.tryParse(_lowCreditsController.text.trim()) ?? 0,
      autoCreditDeduction: _autoCreditDeduction,
      pushNotifications: _pushNotifications,
      emailNotifications: _emailNotifications,
      newJobAlerts: _newJobAlerts,
      newUserAlerts: _newUserAlerts,
      complaintAlerts: _complaintAlerts,
      maintenanceMode: _maintenanceMode,
      twoFactorAuthentication: _twoFactorAuthentication,
      darkMode: _darkMode,
      compactSidebar: _compactSidebar,
      sessionTimeoutMinutes: _sessionTimeoutMinutes,
    );

    setState(() => _saving = true);

    try {
      await _service.saveSettings(updated);
      _settings = updated;

      if (!mounted) return;
      _showMessage('Settings saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Couldn’t save settings. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Reset settings?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'All settings will go back to their default values.',
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.resetSettings();

      final defaults = AdminSettings.defaults();
      setState(() {
        _initialized = false;
      });
      _loadIntoForm(defaults);

      if (!mounted) return;
      _showMessage('Settings reset to defaults.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Couldn’t reset settings. Please try again.', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? kAdminDanger : kAdminSuccess,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.settingsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'We couldn’t load settings. Refresh to try again.',
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: kAdminBrand),
          );
        }

        final settings = AdminSettings.fromMap(snapshot.data!.data());
        _loadIntoForm(settings);

        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsHeader(
                  saving: _saving,
                  onSave: _save,
                  onReset: _reset,
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 1050;

                    final left = Column(
                      children: [
                        _SectionCard(
                          title: 'General Settings',
                          subtitle: 'Basic app information and localization.',
                          icon: Icons.tune_rounded,
                          child: Column(
                            children: [
                              _TextField(
                                controller: _appNameController,
                                label: 'App Name',
                                icon: Icons.apps_rounded,
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _DropdownField(
                                      label: 'Currency',
                                      value: _currency,
                                      items: const ['PKR', 'USD', 'AED'],
                                      onChanged: (value) {
                                        setState(() => _currency = value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DropdownField(
                                      label: 'Time Zone',
                                      value: _timeZone,
                                      items: const [
                                        'Asia/Karachi',
                                        'Asia/Dubai',
                                        'UTC',
                                      ],
                                      onChanged: (value) {
                                        setState(() => _timeZone = value);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _DropdownField(
                                label: 'Date Format',
                                value: _dateFormat,
                                items: const [
                                  'dd MMM yyyy',
                                  'dd/MM/yyyy',
                                  'MM/dd/yyyy',
                                ],
                                onChanged: (value) {
                                  setState(() => _dateFormat = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Support & Legal',
                          subtitle: 'Support contact details and policy links.',
                          icon: Icons.support_agent_rounded,
                          child: Column(
                            children: [
                              // Read-only: the apps show the official
                              // address from code, not from this setting.
                              _TextField(
                                controller: _supportEmailController,
                                label: 'Support Email',
                                icon: Icons.email_outlined,
                                validator: _emailValidator,
                                readOnly: true,
                                helper:
                                    'The official address shown in the '
                                    'customer and worker apps. Changing it '
                                    'requires an app update.',
                              ),
                              const SizedBox(height: 14),
                              _TextField(
                                controller: _supportPhoneController,
                                label: 'Support Phone',
                                icon: Icons.phone_outlined,
                              ),
                              const SizedBox(height: 14),
                              _TextField(
                                controller: _privacyController,
                                label: 'Privacy Policy URL',
                                icon: Icons.privacy_tip_outlined,
                              ),
                              const SizedBox(height: 14),
                              _TextField(
                                controller: _termsController,
                                label: 'Terms & Conditions URL',
                                icon: Icons.description_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Credits Configuration',
                          subtitle:
                              'How workers get and spend lead credits today.',
                          icon: Icons.toll_rounded,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _TextField(
                                      controller: _defaultCreditsController,
                                      label: 'Default Credits',
                                      icon: Icons.wallet_giftcard_rounded,
                                      numberOnly: true,
                                      readOnly: true,
                                      helper:
                                          'New workers start with 0; credits '
                                          'are added by approving payments.',
                                      validator: _numberValidator,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TextField(
                                      controller: _creditsPerLeadController,
                                      label: 'Credits per Lead',
                                      icon: Icons.remove_circle_outline_rounded,
                                      numberOnly: true,
                                      readOnly: true,
                                      helper: 'Fixed at 1 in the worker app.',
                                      validator: _numberValidator,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _TextField(
                                controller: _lowCreditsController,
                                label: 'Low Credit Warning',
                                icon: Icons.warning_amber_rounded,
                                numberOnly: true,
                                helper:
                                    'Saved for reference; the worker app does '
                                    'not read it yet.',
                                validator: _numberValidator,
                              ),
                              const SizedBox(height: 8),
                              _SwitchTile(
                                title: 'Automatic Credit Deduction',
                                subtitle:
                                    'Always on: accepting a lead uses 1 credit in the worker app.',
                                value: true,
                                icon: Icons.autorenew_rounded,
                                onChanged: null,
                                status: 'Always on',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final right = Column(
                      children: [
                        _SectionCard(
                          title: 'Notifications',
                          subtitle: 'Admin alerts and how they’re delivered.',
                          icon: Icons.notifications_active_rounded,
                          child: Column(
                            children: [
                              _SwitchTile(
                                title: 'Push Notifications',
                                subtitle:
                                    'Not connected: push alerts are not sent from this setting.',
                                value: false,
                                icon: Icons.phone_android_rounded,
                                onChanged: null,
                                status: 'Not available yet',
                              ),
                              _SwitchTile(
                                title: 'Email Notifications',
                                subtitle:
                                    'Not connected: no alert emails are sent from this setting.',
                                value: false,
                                icon: Icons.mark_email_read_outlined,
                                onChanged: null,
                                status: 'Not available yet',
                              ),
                              _SwitchTile(
                                title: 'New Job Alerts',
                                subtitle:
                                    'Not connected: new requests appear in Jobs; no alert is sent.',
                                value: false,
                                icon: Icons.work_outline_rounded,
                                onChanged: null,
                                status: 'Not available yet',
                              ),
                              _SwitchTile(
                                title: 'New User Alerts',
                                subtitle:
                                    'Not connected: new sign-ups appear in Users; no alert is sent.',
                                value: false,
                                icon: Icons.person_add_alt_rounded,
                                onChanged: null,
                                status: 'Not available yet',
                              ),
                              _SwitchTile(
                                title: 'Complaint Alerts',
                                subtitle:
                                    'Not connected: complaints appear in Reports; no alert is sent.',
                                value: false,
                                icon: Icons.report_problem_outlined,
                                onChanged: null,
                                status: 'Not available yet',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Security',
                          subtitle: 'Admin access and session controls.',
                          icon: Icons.security_rounded,
                          child: Column(
                            children: [
                              _SwitchTile(
                                title: 'Two-Factor Authentication',
                                subtitle:
                                    'Not enforced: admins sign in with email and password only.',
                                value: false,
                                icon: Icons.phonelink_lock_rounded,
                                onChanged: null,
                                status: 'Not available yet',
                              ),
                              const SizedBox(height: 8),
                              _DropdownField(
                                label: 'Session Timeout',
                                value: _sessionTimeoutMinutes.toString(),
                                items: const ['15', '30', '60', '120'],
                                displayBuilder: (value) => '$value minutes',
                                helper:
                                    'Not enforced yet: admins stay signed in until they sign out.',
                                onChanged: null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Appearance',
                          subtitle: 'How the admin console looks.',
                          icon: Icons.palette_outlined,
                          child: Column(
                            children: [
                              _SwitchTile(
                                title: 'Dark Mode',
                                subtitle: 'The console is light-only for now.',
                                value: false,
                                icon: Icons.dark_mode_outlined,
                                onChanged: null,
                                status: 'Not available yet',
                              ),
                              _SwitchTile(
                                title: 'Compact Sidebar',
                                subtitle:
                                    'Automatic: the sidebar turns compact on medium-width screens.',
                                value: false,
                                icon: Icons.view_sidebar_outlined,
                                onChanged: null,
                                status: 'Automatic',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'System Control',
                          subtitle: 'Critical app-wide controls.',
                          icon: Icons.admin_panel_settings_rounded,
                          child: _DangerSwitchTile(
                            title: 'Maintenance Mode',
                            subtitle:
                                'Not enforced: switching this on would not stop the apps, so it is locked off.',
                            value: false,
                            onChanged: null,
                            status: 'Not available yet',
                          ),
                        ),
                      ],
                    );

                    if (twoColumns) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 18),
                          Expanded(child: right),
                        ],
                      );
                    }

                    return Column(
                      children: [left, const SizedBox(height: 18), right],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _BottomSaveBar(saving: _saving, onSave: _save, onReset: _reset),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }

    final emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _numberValidator(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) {
      return 'Enter a valid number.';
    }
    return null;
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.saving,
    required this.onSave,
    required this.onReset,
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Manage the SkillNova admin console and app configuration.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            // Honest status: nothing in the app, console or Cloud Functions
            // reads these values yet, so no admin should assume a security
            // or maintenance setting is in force.
            Container(
              constraints: const BoxConstraints(maxWidth: 760),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF4E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF7C68F)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: kAdminWarning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only the values you can edit here are saved, and they '
                      'are for reference: the apps don’t read them yet. '
                      'Controls marked “Not available yet” are locked because '
                      'turning them on would not change anything; each one '
                      'says what actually happens today.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: const Color(0xFF7A2E0E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: saving ? null : onReset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      height: 17,
                      width: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(saving ? 'Saving...' : 'Save Changes'),
              style: FilledButton.styleFrom(
                backgroundColor: kAdminBrand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: actions,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            actions,
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6ECF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: kAdminBrand.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: kAdminBrand, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.numberOnly = false,
    this.readOnly = false,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool numberOnly;
  final bool readOnly;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      readOnly: readOnly,
      keyboardType: numberOnly ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        suffixIcon: readOnly ? const Icon(Icons.lock_outline_rounded) : null,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: kAdminBrand, width: 1.6),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.displayBuilder,
    this.helper,
  });

  final String label;
  final String value;
  final List<String> items;

  /// Null shows the field disabled (the setting is not enforced).
  final ValueChanged<String>? onChanged;
  final String Function(String)? displayBuilder;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : items.first;

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 3,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(displayBuilder?.call(item) ?? item),
        );
      }).toList(),
      onChanged: onChanged == null
          ? null
          : (newValue) {
              if (newValue != null) onChanged!(newValue);
            },
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
    this.status,
  });

  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;

  /// Null disables the switch: the setting does not change app behavior.
  final ValueChanged<bool>? onChanged;

  /// Short label such as "Not available yet", shown next to the title.
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: kAdminBrand.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: kAdminBrand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    if (status != null) _StatusPill(status!),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, activeColor: kAdminBrand, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DangerSwitchTile extends StatelessWidget {
  const _DangerSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.status,
  });

  final String title;
  final String subtitle;
  final bool value;

  /// Null disables the switch: the setting does not change app behavior.
  final ValueChanged<bool>? onChanged;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    if (status != null) _StatusPill(status!),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: const Color(0xFFBE123C),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFFDC2626),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Marks a control whose saved value does not (yet) change app behavior.
class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _BottomSaveBar extends StatelessWidget {
  const _BottomSaveBar({
    required this.saving,
    required this.onSave,
    required this.onReset,
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final message = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to apply changes?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Saves the editable reference values.',
                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white60),
              ),
            ],
          );

          final button = FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: const Icon(Icons.save_rounded),
            label: Text(saving ? 'Saving...' : 'Save All Settings'),
            style: FilledButton.styleFrom(
              backgroundColor: kAdminBrand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                message,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: button),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: message),
              TextButton(
                onPressed: saving ? null : onReset,
                child: const Text(
                  'Reset Defaults',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              button,
            ],
          );
        },
      ),
    );
  }
}
