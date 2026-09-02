import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_account_screens.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_edit_profile_screen.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_models.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_repository.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_profile_screen.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_settings_screen.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_support_screens.dart';
import 'package:skill_link/services/skillnova_preferences.dart';

void main() {
  const identity = CustomerIdentity(
    uid: 'customer-1',
    authDisplayName: 'Auth Name',
    email: 'customer@example.com',
    emailVerified: true,
    phone: '+923001234567',
  );

  CustomerProfile profile({Map<String, dynamic>? data}) => CustomerProfile(
    identity: identity,
    data:
        data ??
        const <String, dynamic>{
          'name': 'Ayesha Khan',
          'city': 'Lahore',
          'area': 'Gulberg',
          'address': 'Main Boulevard',
        },
  );

  test(
    'profile model trusts Auth verification and supplies safe fallbacks',
    () {
      final value = CustomerProfile(
        identity: const CustomerIdentity(uid: '1', email: 'a@b.com'),
        data: const {
          'name': 'Very Long Customer Name',
          'phoneVerified': true,
          'emailVerified': true,
        },
      );
      expect(value.name, 'Very Long Customer Name');
      expect(value.identity.emailVerified, isFalse);
      expect(value.identity.phoneVerified, isFalse);
      expect(value.initials, 'VN');
    },
  );

  testWidgets(
    'profile handles no photo, long content, missing and valid location',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeRepository(
        profile(
          data: const {
            'name':
                'A very long customer display name that should wrap without overflowing',
            'city': 'Lahore',
            'area':
                'A deliberately long service area label that remains readable',
            'address':
                'A long customer address used to verify that the location card remains responsive on a narrow device.',
          },
        ),
      );
      await tester.pumpWidget(
        _app(CustomerProfileScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('A very long customer'), findsOneWidget);
      expect(find.byKey(const Key('profile-map-preview')), findsNothing);
      expect(tester.takeException(), isNull);

      repository.value = profile(
        data: const {
          'name': 'Ayesha Khan',
          'city': 'Lahore',
          'locationAdded': true,
          'lat': 31.5204,
          'lng': 74.3587,
        },
      );
      await tester.pumpWidget(
        _app(CustomerProfileScreen(repository: repository)),
      );
      await tester.pump();
      expect(find.byKey(const Key('profile-map-preview')), findsOneWidget);
    },
  );

  testWidgets(
    'edit keeps Auth email and phone read-only and saves only safe fields',
    (tester) async {
      final repository = _FakeRepository(profile());
      await tester.pumpWidget(
        _app(
          CustomerEditProfileScreen(
            initialProfile: repository.value,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      EditableText editableInside(Key key) => tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(EditableText),
        ),
      );
      expect(editableInside(const Key('profile-email-field')).readOnly, isTrue);
      expect(editableInside(const Key('profile-phone-field')).readOnly, isTrue);
      await tester.enterText(
        find.byKey(const Key('profile-name-field')),
        'Updated Name',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile-save-button')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('profile-save-button')));
      await tester.pumpAndSettle();
      expect(repository.lastUpdate?.name, 'Updated Name');
      expect(repository.lastUpdate?.city, 'Lahore');
    },
  );

  testWidgets('photo path exposes upload progress and failure state', (
    tester,
  ) async {
    final repository = _FakeRepository(profile());
    final upload = Completer<String>();
    repository.uploadCompleter = upload;
    await tester.pumpWidget(
      _app(
        CustomerEditProfileScreen(
          initialProfile: repository.value,
          repository: repository,
          imagePicker: _FakeImagePicker('/tmp/customer-photo.jpg'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('profile-photo-editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-gallery')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-save-button')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile-save-button')));
    await tester.pump();
    expect(find.text('Uploading photo…'), findsOneWidget);
    upload.completeError(Exception('upload failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-save-error')), findsOneWidget);
  });

  test(
    'theme and notification preferences survive controller recreation',
    () async {
      final store = _MemoryStore();
      final first = SkillNovaPreferencesController(store: store);
      expect(await first.setThemeMode(ThemeMode.dark), isTrue);
      expect(await first.setLocalNotificationsEnabled(false), isTrue);
      final recreated = SkillNovaPreferencesController(store: store);
      await recreated.load();
      expect(recreated.themeMode, ThemeMode.dark);
      expect(recreated.localNotificationsEnabled, isFalse);
      for (final mode in ThemeMode.values) {
        expect(await recreated.setThemeMode(mode), isTrue);
        expect(recreated.themeMode, mode);
      }
    },
  );

  testWidgets('settings controls all theme modes, local alerts, and logout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = SkillNovaPreferencesController(store: _MemoryStore());
    final repository = _FakeRepository(profile());
    var loggedOut = false;
    await tester.pumpWidget(
      _app(
        CustomerSettingsScreen(
          profile: repository.value,
          preferences: preferences,
          repository: repository,
          onLoggedOut: () => loggedOut = true,
        ),
        mode: ThemeMode.dark,
      ),
    );
    for (final mode in ThemeMode.values) {
      await tester.tap(find.byKey(Key('theme-${mode.name}')));
      await tester.pump();
      expect(preferences.themeMode, mode);
    }
    await tester.tap(find.byKey(const Key('local-notification-switch')));
    await tester.pump();
    expect(preferences.localNotificationsEnabled, isFalse);
    await tester.scrollUntilVisible(
      find.byKey(const Key('logout-button')),
      300,
    );
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(repository.didSignOut, isTrue);
    expect(loggedOut, isTrue);
    expect(find.textContaining('Language'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account and deletion screens communicate trusted and safe state',
    (tester) async {
      await tester.pumpWidget(
        _app(CustomerAccountInformationScreen(profile: profile())),
      );
      expect(find.text('customer@example.com'), findsOneWidget);
      expect(find.text('+923001234567'), findsOneWidget);
      await tester.pumpWidget(_app(const DeleteAccountSafetyScreen()));
      expect(
        find.text('Account deletion is not available yet'),
        findsOneWidget,
      );
      expect(
        find.textContaining('does not perform a partial deletion'),
        findsOneWidget,
      );
    },
  );

  testWidgets('help, safety, privacy, and unavailable Terms states render', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const HelpSupportScreen()));
    expect(find.text('Booking help'), findsOneWidget);
    expect(find.text('Email support'), findsOneWidget);
    await tester.pumpWidget(_app(const CustomerSafetyScreen()));
    expect(find.text('Call Police 15'), findsOneWidget);
    await tester.pumpWidget(_app(const CustomerPrivacyScreen()));
    expect(find.text('Public review identity'), findsOneWidget);
    await tester.pumpWidget(
      _app(const LegalDocumentScreen(title: 'Terms of Service', url: null)),
    );
    expect(find.text('Terms of Service is not available'), findsOneWidget);
  });
}

Widget _app(Widget child, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
  theme: SkillNovaTheme.light,
  darkTheme: SkillNovaTheme.dark,
  themeMode: mode,
  home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
    child: child,
  ),
);

class _FakeRepository implements CustomerProfileRepository {
  _FakeRepository(this.value);
  CustomerProfile value;
  CustomerProfileUpdate? lastUpdate;
  Completer<String>? uploadCompleter;
  bool didSignOut = false;

  @override
  CustomerIdentity? get currentIdentity => value.identity;
  @override
  Future<CustomerProfile> loadProfile() async => value;
  @override
  Stream<CustomerProfile> watchProfile() => Stream.value(value);
  @override
  Future<void> updateProfile(CustomerProfileUpdate update) async =>
      lastUpdate = update;
  @override
  Future<String> uploadProfilePhoto(String path) =>
      uploadCompleter?.future ?? Future.value('https://example.com/photo.jpg');
  @override
  Future<void> signOut() async => didSignOut = true;
}

class _FakeImagePicker implements CustomerProfileImagePicker {
  const _FakeImagePicker(this.path);
  final String? path;
  @override
  Future<String?> pick(ImageSource source) async => path;
}

class _MemoryStore implements SkillNovaPreferenceStore {
  final Map<String, Object> values = {};
  @override
  Future<bool?> readBool(String key) async => values[key] as bool?;
  @override
  Future<String?> readString(String key) async => values[key] as String?;
  @override
  Future<bool> writeBool(String key, bool value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> writeString(String key, String value) async {
    values[key] = value;
    return true;
  }
}
