import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_repository.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_screen.dart';
import 'package:skill_link/screens/worker_screens/navigation/worker_navigation_shell.dart';

void main() {
  Map<String, dynamic> workerData({
    String verification = 'approved',
    bool profileCompleted = true,
    bool canAcceptJobs = true,
    bool blocked = false,
    String accountStatus = 'active',
    int credits = 5,
    bool metrics = true,
    String? photoUrl,
  }) => <String, dynamic>{
    'role': 'worker',
    'name': 'Muhammad Ahmed Professional With A Long Display Name',
    'skill': 'AC Technician',
    'profileCompleted': profileCompleted,
    'identityVerificationStatus': verification,
    'canAcceptJobs': canAcceptJobs,
    'isBlocked': blocked,
    'accountStatus': accountStatus,
    'credits': credits,
    if (metrics) 'rating': 4.9,
    if (metrics) 'totalReviews': 28,
    'profileImageUrl': ?photoUrl,
    'lat': 31.5204,
    'lng': 74.3587,
  };

  WorkerHomeProfile worker(Map<String, dynamic> data) =>
      WorkerHomeProfile(uid: 'worker-1', data: data);

  test('readiness adapter covers every trustworthy gate', () {
    expect(
      WorkerEligibilityAdapter.evaluate(worker(workerData())).state,
      WorkerReadinessState.ready,
    );
    expect(
      WorkerEligibilityAdapter.evaluate(
        worker(workerData(verification: 'pending')),
      ).state,
      WorkerReadinessState.verificationPending,
    );
    expect(
      WorkerEligibilityAdapter.evaluate(
        worker(workerData(verification: 'rejected')),
      ).state,
      WorkerReadinessState.verificationRejected,
    );
    expect(
      WorkerEligibilityAdapter.evaluate(
        worker(workerData(profileCompleted: false)),
      ).state,
      WorkerReadinessState.incompleteProfile,
    );
    expect(
      WorkerEligibilityAdapter.evaluate(
        worker(workerData(blocked: true)),
      ).state,
      WorkerReadinessState.blocked,
    );
    expect(
      WorkerEligibilityAdapter.evaluate(
        worker(workerData(accountStatus: 'inactive')),
      ).state,
      WorkerReadinessState.inactive,
    );
    expect(
      WorkerEligibilityAdapter.evaluate(worker(workerData(credits: 0))).state,
      WorkerReadinessState.needsCredits,
    );
  });

  test(
    'lead eligibility respects status, assignment, and normalized skill',
    () {
      final profile = worker(workerData());
      final eligible = WorkerLeadPreview(
        id: 'lead-1',
        data: const {
          'status': 'searching',
          'category': 'AC Repair',
          'workerId': null,
        },
      );
      expect(eligible.isEligibleFor(profile), isTrue);
      expect(
        WorkerLeadPreview(
          id: 'other',
          data: const {
            'status': 'searching',
            'category': 'AC Repair',
            'workerId': 'worker-2',
          },
        ).isEligibleFor(profile),
        isFalse,
      );
      expect(
        WorkerLeadPreview(
          id: 'done',
          data: const {'status': 'completed', 'category': 'AC Repair'},
        ).isEligibleFor(profile),
        isFalse,
      );
    },
  );

  testWidgets(
    'approved dashboard shows truthful active work, leads, credits, and metrics',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeWorkerHomeRepository(
        profile: worker(
          workerData(photoUrl: 'https://example.invalid/photo.jpg'),
        ),
        active: WorkerActiveJobsSnapshot(
          featured: WorkerActiveJob(
            id: 'job-1',
            customerName: 'Ayesha',
            data: const {
              'status': 'accepted',
              'title': 'Repair bedroom AC',
              'category': 'AC Repair',
              'location': 'Gulberg, Lahore',
              'budget': '2500',
              'urgency': 'Urgent',
            },
          ),
          hasAdditionalJobs: true,
        ),
        leads: const [
          WorkerLeadPreview(
            id: 'lead-1',
            data: {
              'status': 'searching',
              'title': 'AC service needed',
              'category': 'AC Repair',
              'location': 'Model Town',
              'budget': '1800',
              'urgency': 'Normal',
            },
            distanceKm: 3.2,
          ),
        ],
      );
      await tester.pumpWidget(
        _app(WorkerHomeScreen(repository: repository), mode: ThemeMode.dark),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ready for new jobs'), findsOneWidget);
      expect(find.text('Repair bedroom AC'), findsOneWidget);
      expect(
        find.text('Additional active jobs are available in Jobs.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Customer posted budget: Rs. 1800'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Customer posted budget: Rs. 1800'), findsOneWidget);
      expect(find.text('5 available'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('4.9'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('Earnings'), findsNothing);
      expect(find.textContaining('payout'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dashboard handles incomplete profile, no metrics, no active job, and narrow layout',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeWorkerHomeRepository(
        profile: worker(workerData(profileCompleted: false, metrics: false)),
        active: const WorkerActiveJobsSnapshot(),
        leads: const [],
      );
      await tester.pumpWidget(_app(WorkerHomeScreen(repository: repository)));
      await tester.pumpAndSettle();
      expect(find.text('Complete your worker profile'), findsOneWidget);
      expect(find.text('No active job'), findsOneWidget);
      expect(find.text('MN'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Leads are locked'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Leads are locked'), findsOneWidget);
      expect(repository.leadWatchCount, 0);
      expect(find.text('Performance'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zero-credit and no-lead states remain distinct', (tester) async {
    final repository = _FakeWorkerHomeRepository(
      profile: worker(workerData(credits: 0)),
      active: const WorkerActiveJobsSnapshot(),
      leads: const [],
    );
    await tester.pumpWidget(_app(WorkerHomeScreen(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Add lead credits to accept jobs'), findsOneWidget);
    expect(find.text('No new leads'), findsOneWidget);
    expect(repository.leadWatchCount, 1);
    await tester.scrollUntilVisible(
      find.text('0 available'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('0 available'), findsOneWidget);
  });

  for (final statusAndAction in const <(String, String)>[
    ('accepted', 'View job'),
    ('on_the_way', 'Continue job'),
    ('in_progress', 'Continue service'),
  ]) {
    testWidgets(
      'active ${statusAndAction.$1} job uses ${statusAndAction.$2} action',
      (tester) async {
        final repository = _FakeWorkerHomeRepository(
          profile: worker(workerData()),
          active: WorkerActiveJobsSnapshot(
            featured: WorkerActiveJob(
              id: 'job',
              data: {'status': statusAndAction.$1, 'title': 'Current service'},
            ),
          ),
          leads: const [],
        );
        await tester.pumpWidget(
          _app(
            WorkerHomeScreen(
              key: ValueKey(statusAndAction.$1),
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(statusAndAction.$2), findsOneWidget);
      },
    );
  }

  testWidgets(
    'worker shell lazily creates five persistent tabs and back returns Home',
    (tester) async {
      final builds = List<int>.filled(5, 0);
      await tester.pumpWidget(
        _app(
          WorkerNavigationShell(
            screenBuilder: (index, _) {
              builds[index]++;
              return _TestTab(index: index);
            },
          ),
        ),
      );
      expect(builds, [1, 0, 0, 0, 0]);
      for (final label in const [
        'Home',
        'Leads',
        'Jobs',
        'Messages',
        'Profile',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Leads'));
      await tester.pumpAndSettle();
      expect(builds, [1, 1, 0, 0, 0]);
      await tester.tap(find.byKey(const Key('tab-counter')));
      await tester.tap(find.text('Jobs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leads'));
      await tester.pumpAndSettle();
      expect(find.text('tab 1 count 1'), findsOneWidget);
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('tab 0 count 0'), findsOneWidget);
      expect(builds[4], 0);
    },
  );
}

Widget _app(Widget child, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
  theme: SkillNovaTheme.light,
  darkTheme: SkillNovaTheme.dark,
  themeMode: mode,
  home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(1.15)),
    child: child,
  ),
);

class _FakeWorkerHomeRepository implements WorkerHomeRepository {
  _FakeWorkerHomeRepository({
    required this.profile,
    required this.active,
    required this.leads,
  });
  final WorkerHomeProfile profile;
  final WorkerActiveJobsSnapshot active;
  final List<WorkerLeadPreview> leads;
  int leadWatchCount = 0;

  @override
  String? get currentWorkerId => profile.uid;
  @override
  Stream<WorkerHomeProfile> watchProfile() => Stream.value(profile);
  @override
  Stream<WorkerActiveJobsSnapshot> watchActiveJobs() => Stream.value(active);
  @override
  Stream<List<WorkerLeadPreview>> watchLeads(WorkerHomeProfile worker) {
    leadWatchCount++;
    return Stream.value(leads);
  }
}

class _TestTab extends StatefulWidget {
  const _TestTab({required this.index});
  final int index;
  @override
  State<_TestTab> createState() => _TestTabState();
}

class _TestTabState extends State<_TestTab> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton(
      key: const Key('tab-counter'),
      onPressed: () => setState(() => count++),
      child: Text('tab ${widget.index} count $count'),
    ),
  );
}
