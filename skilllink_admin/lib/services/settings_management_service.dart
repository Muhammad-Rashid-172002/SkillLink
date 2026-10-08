import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skilllink_admin/config/support_config.dart';

/// New workers start with no credits (security rules forbid granting them at
/// sign-up); credits are added when an admin approves a payment.
const int kFixedDefaultWorkerCredits = 0;

/// Accepting a lead always costs one credit in the worker app.
const int kFixedCreditsPerLead = 1;

class SettingsManagementService {
  SettingsManagementService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection('admin_settings').doc('general');

  Stream<DocumentSnapshot<Map<String, dynamic>>> settingsStream() {
    return _settingsDoc.snapshots();
  }

  Future<void> saveSettings(AdminSettings settings) async {
    await _settingsDoc.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> resetSettings() async {
    await _settingsDoc.set({
      ...AdminSettings.defaults().toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

class AdminSettings {
  const AdminSettings({
    required this.appName,
    required this.supportEmail,
    required this.supportPhone,
    required this.privacyPolicyUrl,
    required this.termsUrl,
    required this.currency,
    required this.timeZone,
    required this.dateFormat,
    required this.defaultWorkerCredits,
    required this.creditsPerLead,
    required this.lowCreditWarning,
    required this.autoCreditDeduction,
    required this.pushNotifications,
    required this.emailNotifications,
    required this.newJobAlerts,
    required this.newUserAlerts,
    required this.complaintAlerts,
    required this.maintenanceMode,
    required this.twoFactorAuthentication,
    required this.sessionTimeoutMinutes,
    required this.darkMode,
    required this.compactSidebar,
  });

  final String appName;
  final String supportEmail;
  final String supportPhone;
  final String privacyPolicyUrl;
  final String termsUrl;
  final String currency;
  final String timeZone;
  final String dateFormat;

  final int defaultWorkerCredits;
  final int creditsPerLead;
  final int lowCreditWarning;
  final bool autoCreditDeduction;

  final bool pushNotifications;
  final bool emailNotifications;
  final bool newJobAlerts;
  final bool newUserAlerts;
  final bool complaintAlerts;

  final bool maintenanceMode;
  final bool twoFactorAuthentication;
  final int sessionTimeoutMinutes;

  final bool darkMode;
  final bool compactSidebar;

  factory AdminSettings.defaults() {
    return const AdminSettings(
      appName: 'SkillNova',
      supportEmail: kSkillNovaSupportEmail,
      supportPhone: '',
      privacyPolicyUrl: 'https://skilllinkprivacypolicy.vercel.app',
      termsUrl: '',
      currency: 'PKR',
      timeZone: 'Asia/Karachi',
      dateFormat: 'dd MMM yyyy',
      defaultWorkerCredits: kFixedDefaultWorkerCredits,
      creditsPerLead: kFixedCreditsPerLead,
      lowCreditWarning: 3,
      autoCreditDeduction: true,
      pushNotifications: true,
      emailNotifications: true,
      newJobAlerts: true,
      newUserAlerts: true,
      complaintAlerts: true,
      maintenanceMode: false,
      twoFactorAuthentication: false,
      sessionTimeoutMinutes: 30,
      darkMode: false,
      compactSidebar: false,
    );
  }

  factory AdminSettings.fromMap(Map<String, dynamic>? data) {
    final defaults = AdminSettings.defaults();
    if (data == null) return defaults;

    return AdminSettings(
      appName: _string(data['appName'], defaults.appName),
      // The app shows the official constant, so the console does too;
      // a stale stored value must not suggest a different address.
      supportEmail: kSkillNovaSupportEmail,
      supportPhone: _string(data['supportPhone'], defaults.supportPhone),
      privacyPolicyUrl: _string(
        data['privacyPolicyUrl'],
        defaults.privacyPolicyUrl,
      ),
      termsUrl: _string(data['termsUrl'], defaults.termsUrl),
      currency: _string(data['currency'], defaults.currency),
      timeZone: _string(data['timeZone'], defaults.timeZone),
      dateFormat: _string(data['dateFormat'], defaults.dateFormat),
      // Behavior fixed in the apps/rules; show what really happens rather
      // than a stored value nothing reads.
      defaultWorkerCredits: kFixedDefaultWorkerCredits,
      creditsPerLead: kFixedCreditsPerLead,
      lowCreditWarning: _integer(
        data['lowCreditWarning'],
        defaults.lowCreditWarning,
      ),
      autoCreditDeduction: true,
      pushNotifications: _boolean(
        data['pushNotifications'],
        defaults.pushNotifications,
      ),
      emailNotifications: _boolean(
        data['emailNotifications'],
        defaults.emailNotifications,
      ),
      newJobAlerts: _boolean(data['newJobAlerts'], defaults.newJobAlerts),
      newUserAlerts: _boolean(data['newUserAlerts'], defaults.newUserAlerts),
      complaintAlerts: _boolean(
        data['complaintAlerts'],
        defaults.complaintAlerts,
      ),
      // Not implemented anywhere, so never reported as on.
      maintenanceMode: false,
      twoFactorAuthentication: false,
      sessionTimeoutMinutes: _integer(
        data['sessionTimeoutMinutes'],
        defaults.sessionTimeoutMinutes,
      ),
      darkMode: false,
      compactSidebar: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appName': appName,
      'supportEmail': supportEmail,
      'supportPhone': supportPhone,
      'privacyPolicyUrl': privacyPolicyUrl,
      'termsUrl': termsUrl,
      'currency': currency,
      'timeZone': timeZone,
      'dateFormat': dateFormat,
      'defaultWorkerCredits': defaultWorkerCredits,
      'creditsPerLead': creditsPerLead,
      'lowCreditWarning': lowCreditWarning,
      'autoCreditDeduction': autoCreditDeduction,
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'newJobAlerts': newJobAlerts,
      'newUserAlerts': newUserAlerts,
      'complaintAlerts': complaintAlerts,
      'maintenanceMode': maintenanceMode,
      'twoFactorAuthentication': twoFactorAuthentication,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,
      'darkMode': darkMode,
      'compactSidebar': compactSidebar,
    };
  }

  AdminSettings copyWith({
    String? appName,
    String? supportEmail,
    String? supportPhone,
    String? privacyPolicyUrl,
    String? termsUrl,
    String? currency,
    String? timeZone,
    String? dateFormat,
    int? defaultWorkerCredits,
    int? creditsPerLead,
    int? lowCreditWarning,
    bool? autoCreditDeduction,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? newJobAlerts,
    bool? newUserAlerts,
    bool? complaintAlerts,
    bool? maintenanceMode,
    bool? twoFactorAuthentication,
    int? sessionTimeoutMinutes,
    bool? darkMode,
    bool? compactSidebar,
  }) {
    return AdminSettings(
      appName: appName ?? this.appName,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      privacyPolicyUrl: privacyPolicyUrl ?? this.privacyPolicyUrl,
      termsUrl: termsUrl ?? this.termsUrl,
      currency: currency ?? this.currency,
      timeZone: timeZone ?? this.timeZone,
      dateFormat: dateFormat ?? this.dateFormat,
      defaultWorkerCredits: defaultWorkerCredits ?? this.defaultWorkerCredits,
      creditsPerLead: creditsPerLead ?? this.creditsPerLead,
      lowCreditWarning: lowCreditWarning ?? this.lowCreditWarning,
      autoCreditDeduction: autoCreditDeduction ?? this.autoCreditDeduction,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      newJobAlerts: newJobAlerts ?? this.newJobAlerts,
      newUserAlerts: newUserAlerts ?? this.newUserAlerts,
      complaintAlerts: complaintAlerts ?? this.complaintAlerts,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      twoFactorAuthentication:
          twoFactorAuthentication ?? this.twoFactorAuthentication,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      darkMode: darkMode ?? this.darkMode,
      compactSidebar: compactSidebar ?? this.compactSidebar,
    );
  }

  static String _string(dynamic value, String fallback) {
    return value is String ? value : fallback;
  }

  static int _integer(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _boolean(dynamic value, bool fallback) {
    return value is bool ? value : fallback;
  }
}
