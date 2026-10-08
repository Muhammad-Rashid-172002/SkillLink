import 'package:flutter_test/flutter_test.dart';
import 'package:skilllink_admin/config/support_config.dart';
import 'package:skilllink_admin/services/settings_management_service.dart';

/// Settings nothing enforces must never be reported as active, whatever an
/// older console version stored.
void main() {
  test('unenforced controls read as off and fixed values as fixed', () {
    final settings = AdminSettings.fromMap({
      'maintenanceMode': true,
      'twoFactorAuthentication': true,
      'darkMode': true,
      'compactSidebar': true,
      'autoCreditDeduction': false,
      'defaultWorkerCredits': 50,
      'creditsPerLead': 7,
      'supportEmail': 'support@skillnova.com',
      'appName': 'SkillNova',
    });
    expect(settings.maintenanceMode, isFalse);
    expect(settings.twoFactorAuthentication, isFalse);
    expect(settings.darkMode, isFalse);
    expect(settings.compactSidebar, isFalse);
    expect(settings.autoCreditDeduction, isTrue);
    expect(settings.defaultWorkerCredits, 0);
    expect(settings.creditsPerLead, 1);
    expect(settings.supportEmail, kSkillNovaSupportEmail);
    expect(settings.supportEmail, 'support@korvenzatech.com');
  });

  test('defaults match real behavior', () {
    final defaults = AdminSettings.defaults();
    expect(defaults.defaultWorkerCredits, kFixedDefaultWorkerCredits);
    expect(defaults.creditsPerLead, kFixedCreditsPerLead);
    expect(defaults.maintenanceMode, isFalse);
  });
}
