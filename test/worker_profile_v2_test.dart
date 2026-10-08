import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/Role_selection_screen/role_selection.dart';
import 'package:skill_link/screens/customer_screens/profile/customer_account_screens.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_account_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_edit_profile_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_help_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_privacy_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_models.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_repository.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_profile_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_safety_screen.dart';
import 'package:skill_link/screens/worker_screens/profile/worker_settings_screen.dart';
import 'package:skill_link/services/skillnova_preferences.dart';

void main() {
  const identity = WorkerIdentity(
    uid: 'worker-10',
    authDisplayName: 'Auth Worker',
    email: 'worker@example.com',
    emailVerified: true,
    phone: '+923001234567',
  );

  Map<String, dynamic> workerData({
    String role = 'worker',
    String skill = 'Electrician',
    String verification = 'approved',
    bool profileCompleted = true,
    bool canAcceptJobs = true,
    bool isBlocked = false,
    String accountStatus = 'active',
    int credits = 4,
  }) => <String, dynamic>{
    'role': role,
    'name': 'A very long professional worker name for responsive testing',
    'skill': skill,
    'experience': 'More than five years of residential experience',
    'hourlyRate': '2500',
    'city': 'Lahore',
    'area': 'A long service area across Gulberg and nearby communities',
    'bio':
        'Careful residential service with transparent communication and a deliberately long professional description.',
    'identityVerificationStatus': verification,
    'profileCompleted': profileCompleted,
    'canAcceptJobs': canAcceptJobs,
    'isBlocked': isBlocked,
    'accountStatus': accountStatus,
    'credits': credits,
    'rating': 4.8,
    'totalReviews': 19,
    'isOnline': true,
  };

  WorkerProfile profile({Map<String, dynamic>? data}) =>
      WorkerProfile(identity: identity, data: data ?? workerData());

  WorkerReadiness readiness(Map<String, dynamic> data) =>
      WorkerEligibilityAdapter.evaluate(
        WorkerHomeProfile(uid: identity.uid, data: data),
      );

  test('canonical adapters preserve public-profile read aliases', () {
    final value = WorkerProfile(
      identity: identity,
      data: const {
        'fullName': 'Legacy Name',
        'photoUrl': 'photo',
        'mainSkill': 'Plumber',
        'startingRate': 1200,
        'about': 'Legacy bio',
        'experienceYears': '6 years',
        'serviceArea': 'Rawalpindi',
      },
    );
    expect(value.name, 'Legacy Name');
    expect(value.photoUrl, 'photo');
    expect(value.skill, 'Plumber');
    expect(value.hourlyRate, '1200');
    expect(value.bio, 'Legacy bio');
    expect(value.experience, '6 years');
    expect(value.serviceArea, 'Rawalpindi');
  });

  test('canonical values take precedence over legacy aliases', () {
    final value = profile(
      data: {
        ...workerData(),
        'name': 'Canonical',
        'fullName': 'Legacy',
        'profileImageUrl': 'canonical-photo',
        'photoUrl': 'legacy-photo',
        'hourlyRate': '3000',
        'startingRate': '1000',
      },
    );
    expect(value.name, 'Canonical');
    expect(value.photoUrl, 'canonical-photo');
    expect(value.hourlyRate, '3000');
  });

  test('verification presentation covers actual stored states', () {
    expect(
      profile(
        data: workerData(verification: 'not_submitted'),
      ).verificationLabel,
      'Not started',
    );
    expect(
      profile(data: workerData(verification: 'pending')).verificationLabel,
      'Pending review',
    );
    expect(
      profile(data: workerData(verification: 'approved')).verificationLabel,
      'Approved',
    );
    expect(
      profile(data: workerData(verification: 'rejected')).verificationLabel,
      'Rejected',
    );
    expect(
      profile(
        data: workerData(verification: 'more_information_required'),
      ).verificationLabel,
      'More information required',
    );
  });

  test('rate validation accepts positive values and normalizes safely', () {
    expect(validateWorkerRate('2,500.50'), isNull);
    expect(normalizedWorkerRate('2,500.50'), '2500.50');
    expect(validateWorkerRate('0'), isNotNull);
    expect(validateWorkerRate('-3'), isNotNull);
    expect(validateWorkerRate('not a number'), isNotNull);
  });

  test('readiness blocks incomplete profile', () {
    expect(
      readiness(workerData(profileCompleted: false)).state,
      WorkerReadinessState.incompleteProfile,
    );
  });

  test('readiness blocks missing skill', () {
    expect(
      readiness(workerData(skill: '')).state,
      WorkerReadinessState.missingSkill,
    );
  });

  test('readiness presents pending verification', () {
    expect(
      readiness(workerData(verification: 'pending')).state,
      WorkerReadinessState.verificationPending,
    );
  });

  test('readiness presents rejected verification', () {
    expect(
      readiness(workerData(verification: 'rejected')).state,
      WorkerReadinessState.verificationRejected,
    );
  });

  test('readiness blocks restricted account', () {
    expect(
      readiness(workerData(isBlocked: true)).state,
      WorkerReadinessState.blocked,
    );
  });

  test('readiness blocks inactive account', () {
    expect(
      readiness(workerData(accountStatus: 'inactive')).state,
      WorkerReadinessState.inactive,
    );
  });

  test('readiness reports accepting jobs disabled', () {
    expect(
      readiness(workerData(canAcceptJobs: false)).state,
      WorkerReadinessState.acceptanceDisabled,
    );
  });

  test('zero credits permits lead receipt but not acceptance', () {
    final value = readiness(workerData(credits: 0));
    expect(value.state, WorkerReadinessState.needsCredits);
    expect(value.canReceiveLeads, isTrue);
    expect(value.canAcceptLead, isFalse);
  });

  test('fully eligible funded worker is ready', () {
    expect(readiness(workerData()).state, WorkerReadinessState.ready);
  });

  test('legacy isOnline never overrides canAcceptJobs', () {
    final data = workerData(canAcceptJobs: false)..['isOnline'] = true;
    expect(readiness(data).state, WorkerReadinessState.acceptanceDisabled);
  });

  testWidgets(
    'profile presents incomplete pending rejected inactive and zero-credit states',
    (tester) async {
      final cases = <(Map<String, dynamic>, String)>[
        (workerData(profileCompleted: false), 'Complete your worker profile'),
        (workerData(verification: 'pending'), 'Verification under review'),
        (workerData(verification: 'rejected'), 'Verification needs attention'),
        (workerData(accountStatus: 'inactive'), 'Account is not active'),
        (workerData(credits: 0), 'Add lead credits to accept jobs'),
      ];
      for (final item in cases) {
        await tester.pumpWidget(
          _app(
            WorkerProfileScreen(
              key: ValueKey(item.$2),
              repository: _FakeWorkerProfileRepository(profile(data: item.$1)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(item.$2), findsWidgets);
      }
    },
  );

  testWidgets('complete profile shows only maintained summary data', (
    tester,
  ) async {
    final repository = _FakeWorkerProfileRepository(profile());
    await tester.pumpWidget(_app(WorkerProfileScreen(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Ready for new jobs'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('4.8'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('19 reviews'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Lead credits'), findsWidgets);
    expect(find.textContaining('Earnings'), findsNothing);
    expect(find.textContaining('ONLINE'), findsNothing);
    expect(find.textContaining('completed job count'), findsNothing);
  });

  testWidgets('profile handles long content and missing photo at 320x720', (
    tester,
  ) async {
    await _setSize(tester, const Size(320, 720));
    final repository = _FakeWorkerProfileRepository(profile());
    await tester.pumpWidget(_app(WorkerProfileScreen(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.textContaining('A very long professional'), findsOneWidget);
    expect(find.text('AT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile renders in dark mode at 390x844 without overflow', (
    tester,
  ) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        WorkerProfileScreen(
          repository: _FakeWorkerProfileRepository(profile()),
        ),
        mode: ThemeMode.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile handles long service bio and missing optional fields', (
    tester,
  ) async {
    await _setSize(tester, const Size(390, 844));
    final data = workerData(skill: 'Internet Technician')
      ..['bio'] = List.filled(18, 'Detailed professional service').join(' ')
      ..['experience'] = ''
      ..['hourlyRate'] = ''
      ..['city'] = ''
      ..['area'] = '';
    await tester.pumpWidget(
      _app(
        WorkerProfileScreen(
          repository: _FakeWorkerProfileRepository(profile(data: data)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Internet Technician'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Professional bio'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Not added'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ineligible worker cannot enable accepting jobs', (tester) async {
    final blocked = profile(data: workerData(isBlocked: true));
    await tester.pumpWidget(
      _app(
        WorkerProfileScreen(repository: _FakeWorkerProfileRepository(blocked)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('worker-accepting-jobs-toggle')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('worker-accepting-jobs-toggle')),
    );
    expect(tile.onChanged, isNull);
    expect(find.text('Account access restricted'), findsWidgets);
  });

  testWidgets('eligible worker can confirm accepting-jobs change', (
    tester,
  ) async {
    final repository = _FakeWorkerProfileRepository(
      profile(data: workerData(canAcceptJobs: false)),
    );
    await tester.pumpWidget(_app(WorkerProfileScreen(repository: repository)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('worker-accepting-jobs-toggle')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('worker-accepting-jobs-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accept new jobs?'), findsOneWidget);
    await tester.tap(find.text('Accept jobs'));
    await tester.pumpAndSettle();
    expect(repository.acceptingJobs, isTrue);
  });

  testWidgets('profile integrations use canonical callbacks', (tester) async {
    var verification = 0;
    var credits = 0;
    var reviews = 0;
    var completed = 0;
    var public = 0;
    await tester.pumpWidget(
      _app(
        WorkerProfileScreen(
          repository: _FakeWorkerProfileRepository(profile()),
          onVerification: () => verification++,
          onCredits: () => credits++,
          onReviews: () => reviews++,
          onCompletedJobs: () => completed++,
          onPublicProfile: () => public++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in [
      'Public profile preview',
      'Verification: Approved',
      'Lead credits',
      'Reviews',
      'Completed jobs',
    ]) {
      final target = find.widgetWithText(ListTile, label);
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pump();
    }
    expect(
      (public, verification, credits, reviews, completed),
      (1, 1, 1, 1, 1),
    );
  });

  testWidgets('profile logout confirms, signs out, and delegates navigation', (
    tester,
  ) async {
    final repository = _FakeWorkerProfileRepository(profile());
    var loggedOut = false;
    await tester.pumpWidget(
      _app(
        WorkerProfileScreen(
          repository: repository,
          onLoggedOut: () => loggedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('worker-profile-logout'));
    await tester.scrollUntilVisible(
      button,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(repository.signedOut, isTrue);
    expect(loggedOut, isTrue);
  });

  testWidgets('edit shows Auth identity as non-editable account information', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        WorkerEditProfileScreen(
          profile: profile(),
          repository: _FakeWorkerProfileRepository(profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('worker@example.com'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('worker@example.com'), findsOneWidget);
    expect(find.text('+923001234567'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'worker@example.com'),
      findsNothing,
    );
    expect(find.widgetWithText(TextFormField, '+923001234567'), findsNothing);
  });

  testWidgets('valid edit saves canonical supported service and safe fields', (
    tester,
  ) async {
    final repository = _FakeWorkerProfileRepository(profile());
    var saved = false;
    await tester.pumpWidget(
      _app(
        WorkerEditProfileScreen(
          profile: profile(),
          repository: repository,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('worker-edit-city')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('worker-edit-city')),
      'Islamabad',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('worker-edit-bio')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('worker-edit-bio')),
      'Updated professional bio',
    );
    final save = find.byKey(const ValueKey('worker-edit-save'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(repository.lastUpdate?.skill, 'Electrician');
    expect(repository.lastUpdate?.bio, 'Updated professional bio');
    expect(repository.lastUpdate?.city, 'Islamabad');
  });

  testWidgets(
    'full form blocks an off-screen invalid field with keyboard open',
    (tester) async {
      await _setSize(tester, const Size(320, 720));
      final data = workerData()..['experience'] = '';
      final value = profile(data: data);
      final repository = _FakeWorkerProfileRepository(value);
      await tester.pumpWidget(
        _app(WorkerEditProfileScreen(profile: value, repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-edit-name')));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('worker-edit-save')),
      );
      save.onPressed!.call();
      await tester.pump();
      expect(find.text('Add your experience'), findsOneWidget);
      expect(repository.lastUpdate, isNull);
    },
  );

  testWidgets(
    'save keeps the old profile photo when no replacement is selected',
    (tester) async {
      final data = workerData()
        ..['profileImageUrl'] = 'https://example.test/old.jpg';
      final value = profile(data: data);
      final repository = _FakeWorkerProfileRepository(value);
      await tester.pumpWidget(
        _app(
          WorkerEditProfileScreen(
            profile: value,
            repository: repository,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('worker-edit-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.lastUpdate?.photoUrl, 'https://example.test/old.jpg');
    },
  );

  testWidgets(
    'edit shows save loading state and completes once write finishes',
    (tester) async {
      final repository = _FakeWorkerProfileRepository(profile())
        ..holdUpdate = true;
      await tester.pumpWidget(
        _app(
          WorkerEditProfileScreen(
            profile: profile(),
            repository: repository,
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('worker-edit-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      repository.completeUpdate();
      await tester.pumpAndSettle();
      expect(repository.lastUpdate, isNotNull);
    },
  );

  testWidgets('edit reports profile write failure without claiming success', (
    tester,
  ) async {
    final repository = _FakeWorkerProfileRepository(profile())
      ..failUpdate = true;
    await tester.pumpWidget(
      _app(WorkerEditProfileScreen(profile: profile(), repository: repository)),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('worker-edit-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Profile save failed safely.'), findsOneWidget);
  });

  testWidgets('edit rejects an invalid service rate', (tester) async {
    final repository = _FakeWorkerProfileRepository(profile());
    await tester.pumpWidget(
      _app(WorkerEditProfileScreen(profile: profile(), repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('worker-edit-rate')), '0');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('worker-edit-save'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Enter a valid positive service rate'), findsOneWidget);
    expect(repository.lastUpdate, isNull);
  });

  testWidgets('edit exposes photo upload progress', (tester) async {
    final repository = _FakeWorkerProfileRepository(profile())
      ..holdUpload = true;
    await tester.pumpWidget(
      _app(
        WorkerEditProfileScreen(
          profile: profile(),
          repository: repository,
          imagePicker: const _FakeImagePicker('/tmp/worker-profile.jpg'),
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-edit-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-photo-gallery')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('worker-edit-save'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('worker-photo-upload-progress')),
      findsOneWidget,
    );
    repository.completeUpload();
    await tester.pumpAndSettle();
    expect(
      repository.lastUpdate?.photoUrl,
      'https://example.test/new-photo.jpg',
    );
  });

  testWidgets('edit reports photo upload failure without saving profile', (
    tester,
  ) async {
    final repository = _FakeWorkerProfileRepository(profile())
      ..failUpload = true;
    await tester.pumpWidget(
      _app(
        WorkerEditProfileScreen(
          profile: profile(),
          repository: repository,
          imagePicker: const _FakeImagePicker('/tmp/worker-profile.jpg'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-edit-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-photo-gallery')));
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('worker-edit-save'));
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Photo upload failed safely.'), findsOneWidget);
    expect(repository.lastUpdate, isNull);
  });

  testWidgets(
    'settings persists System Light and Dark through shared controller',
    (tester) async {
      final store = _FakePreferenceStore();
      final preferences = SkillNovaPreferencesController(store: store);
      await preferences.load();
      await tester.pumpWidget(
        _app(
          WorkerSettingsScreen(
            profile: profile(),
            preferences: preferences,
            repository: _FakeWorkerProfileRepository(profile()),
          ),
        ),
      );
      for (final mode in ['light', 'dark', 'system']) {
        await tester.tap(find.byKey(ValueKey('theme-$mode')));
        await tester.pump();
        expect(store.strings[SkillNovaPreferencesController.themeKey], mode);
      }
    },
  );

  testWidgets('settings describes foreground alerts and has no fake language', (
    tester,
  ) async {
    final preferences = SkillNovaPreferencesController(
      store: _FakePreferenceStore(),
    );
    await preferences.load();
    await tester.pumpWidget(
      _app(
        WorkerSettingsScreen(
          profile: profile(),
          preferences: preferences,
          repository: _FakeWorkerProfileRepository(profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('In-app alerts'), findsOneWidget);
    expect(
      find.textContaining('Server and system notifications may still arrive'),
      findsOneWidget,
    );
    expect(find.textContaining('Language'), findsNothing);
  });

  testWidgets('foreground alert preference persists locally', (tester) async {
    final store = _FakePreferenceStore();
    final preferences = SkillNovaPreferencesController(store: store);
    await preferences.load();
    await tester.pumpWidget(
      _app(
        WorkerSettingsScreen(
          profile: profile(),
          preferences: preferences,
          repository: _FakeWorkerProfileRepository(profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('worker-foreground-alert-switch')),
    );
    await tester.pump();
    expect(
      store.bools[SkillNovaPreferencesController.notificationKey],
      isFalse,
    );
  });

  testWidgets('settings routes to worker account privacy help and safety', (
    tester,
  ) async {
    final preferences = SkillNovaPreferencesController(
      store: _FakePreferenceStore(),
    );
    await preferences.load();
    await tester.pumpWidget(
      _app(
        WorkerSettingsScreen(
          profile: profile(),
          preferences: preferences,
          repository: _FakeWorkerProfileRepository(profile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cases = <(String, Type)>[
      ('Account information', WorkerAccountInformationScreen),
      ('Your data', WorkerPrivacyScreen),
      ('Help & Support', WorkerHelpScreen),
      ('Safety', WorkerSafetyScreen),
    ];
    for (final item in cases) {
      final target = find.widgetWithText(ListTile, item.$1);
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(item.$2), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('default logout clears protected navigation history', (
    tester,
  ) async {
    final repository = _FakeWorkerProfileRepository(profile());
    await tester.pumpWidget(_app(WorkerProfileScreen(repository: repository)));
    await tester.pumpAndSettle();
    final logout = find.byKey(const ValueKey('worker-profile-logout'));
    await tester.scrollUntilVisible(
      logout,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(logout);
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.byType(WorkerProfileScreen), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WorkerProfileScreen), findsNothing);
  });

  testWidgets(
    'worker account uses Auth email and phone without internal fields',
    (tester) async {
      await tester.pumpWidget(
        _app(WorkerAccountInformationScreen(profile: profile())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verified email'), findsOneWidget);
      expect(find.text('Verified phone'), findsOneWidget);
      expect(find.text('worker@example.com'), findsOneWidget);
      expect(find.text(identity.uid), findsNothing);
      expect(find.textContaining('FCM'), findsNothing);
      expect(find.textContaining('CNIC'), findsNothing);
    },
  );

  testWidgets('deletion surface never claims client-side success', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const WorkerDeleteAccountScreen()));
    expect(
      find.text('Account deletion is handled through support'),
      findsOneWidget,
    );
    expect(
      find.textContaining('does not perform a partial deletion'),
      findsOneWidget,
    );
    expect(find.textContaining('deleted successfully'), findsNothing);
  });

  testWidgets('privacy identifies public and private worker data', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const WorkerPrivacyScreen()));
    expect(find.text('Public professional profile'), findsOneWidget);
    expect(find.text('Private identity and account data'), findsOneWidget);
    expect(find.textContaining('background tracking'), findsOneWidget);
  });

  testWidgets(
    'safety copy preserves foreground-only and manual police semantics',
    (tester) async {
      await tester.pumpWidget(_app(const WorkerSafetyScreen()));
      expect(find.textContaining('foreground-only'), findsOneWidget);
      expect(
        find.textContaining('does not automatically contact police'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('worker-call-police')), findsOneWidget);
    },
  );

  testWidgets('About uses supplied package version and build metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AboutSkillNovaScreen(
          packageInfo: Future.value(
            PackageInfo(
              appName: 'SkillNova',
              packageName: 'com.skillnova.app',
              version: '2.3.4',
              buildNumber: '56',
              buildSignature: '',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Version 2.3.4 (56)'), findsOneWidget);
  });
}

Widget _app(Widget home, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
  theme: SkillNovaTheme.light,
  darkTheme: SkillNovaTheme.dark,
  themeMode: mode,
  home: home,
);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeWorkerProfileRepository implements WorkerProfileRepository {
  _FakeWorkerProfileRepository(this.value);

  WorkerProfile value;
  WorkerProfileUpdate? lastUpdate;
  bool? acceptingJobs;
  bool signedOut = false;
  bool failUpload = false;
  bool holdUpload = false;
  bool failUpdate = false;
  bool holdUpdate = false;
  Completer<String>? _uploadCompleter;
  Completer<void>? _updateCompleter;

  @override
  WorkerIdentity? get currentIdentity => value.identity;

  @override
  Future<WorkerProfile> loadProfile() async => value;

  @override
  Stream<WorkerProfile> watchProfile() => Stream.value(value);

  @override
  Future<void> updateProfile(WorkerProfileUpdate update) async {
    if (failUpdate) {
      throw const WorkerProfileException('Profile save failed safely.');
    }
    lastUpdate = update;
    if (holdUpdate) {
      _updateCompleter = Completer<void>();
      return _updateCompleter!.future;
    }
  }

  @override
  Future<String> uploadProfilePhoto(
    String path, {
    ValueChanged<double>? onProgress,
  }) async {
    if (failUpload) {
      throw const WorkerProfileException('Photo upload failed safely.');
    }
    onProgress?.call(.45);
    if (holdUpload) {
      _uploadCompleter = Completer<String>();
      return _uploadCompleter!.future;
    }
    return 'https://example.test/new-photo.jpg';
  }

  void completeUpload() {
    _uploadCompleter?.complete('https://example.test/new-photo.jpg');
  }

  void completeUpdate() {
    _updateCompleter?.complete();
  }

  @override
  Future<void> setAcceptingJobs(bool accepting) async {
    acceptingJobs = accepting;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class _FakeImagePicker implements WorkerProfileImagePicker {
  const _FakeImagePicker(this.path);
  final String? path;

  @override
  Future<String?> pick(ImageSource source) async => path;
}

class _FakePreferenceStore implements SkillNovaPreferenceStore {
  final Map<String, String> strings = {};
  final Map<String, bool> bools = {};

  @override
  Future<bool?> readBool(String key) async => bools[key];

  @override
  Future<String?> readString(String key) async => strings[key];

  @override
  Future<bool> writeBool(String key, bool value) async {
    bools[key] = value;
    return true;
  }

  @override
  Future<bool> writeString(String key, String value) async {
    strings[key] = value;
    return true;
  }
}
