abstract final class SkillNovaSupportConfig {
  /// The single official SkillNova support address, shown by the customer
  /// and worker apps. The admin console mirrors it in
  /// `skilllink_admin/lib/config/support_config.dart`.
  static const String supportEmail = 'support@korvenzatech.com';
  static final Uri privacyPolicyUrl = Uri.parse(
    'https://skillnova-privacy-center.vercel.app/',
  );

  /// No approved Terms document is configured in the current project.
  static const Uri? termsOfServiceUrl = null;

  /// No approved company or product website is configured in the project.
  static const Uri? companyWebsiteUrl = null;
  static const String emergencyNumber = '15';
}
