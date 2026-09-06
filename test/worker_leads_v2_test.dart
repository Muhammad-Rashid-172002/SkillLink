import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_models.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_leads_repository.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_leads_screen.dart';
import 'package:skill_link/screens/worker_screens/navigation/worker_navigation_scope.dart';

void main() {
  test('lead adapter normalizes real fields without fallback coordinates', () {
    final lead = _lead(
      id: 'lead-1',
      category: 'AC Repair',
      budget: '5,000',
      lat: 33.6844,
      lng: 73.0479,
      images: const ['https://example.com/request.jpg', 'not-a-url'],
    );
    expect(lead.postedBudget, 'Rs. 5,000');
    expect(lead.budgetValue, 5000);
    expect(lead.coordinate?.latitude, 33.6844);
    expect(lead.approximateMapCoordinate?.latitude, 33.68);
    expect(lead.imageUrls, hasLength(1));
    expect(lead.publicServiceArea, isNot(contains('33.6844')));
    expect(_lead(id: 'bad', lat: 110, lng: 300).coordinate, isNull);
  });

  test(
    'visibility excludes unrelated, claimed, cancelled and completed leads',
    () {
      final worker = _worker();
      expect(_lead(id: 'ok').isVisibleTo(worker), isTrue);
      expect(
        _lead(id: 'alias', category: 'AC Technician').isVisibleTo(worker),
        isTrue,
      );
      expect(
        _lead(id: 'other', category: 'Plumber').isVisibleTo(worker),
        isFalse,
      );
      expect(
        _lead(id: 'claimed', workerId: 'worker-2').isVisibleTo(worker),
        isFalse,
      );
      expect(
        _lead(id: 'cancelled', status: 'cancelled').isVisibleTo(worker),
        isFalse,
      );
      expect(
        _lead(id: 'done', status: 'completed').isVisibleTo(worker),
        isFalse,
      );
    },
  );

  test('search, filters and every supported sort are deterministic', () {
    final now = DateTime(2026, 9, 3, 12);
    final leads = [
      _lead(
        id: 'urgent-near',
        title: 'Long AC service title for bedroom cooling issue',
        urgency: 'Urgent',
        budget: '9000',
        distance: 2,
        createdAt: now.subtract(const Duration(hours: 2)),
        customer: const WorkerLeadCustomer(
          id: 'c1',
          name: 'Ayesha Khan',
          area: 'F-7',
          city: 'Islamabad',
        ),
      ),
      _lead(
        id: 'normal-far',
        title: 'Office cooling',
        urgency: 'Normal',
        budget: '3000',
        distance: 20,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];

    expect(
      filterAndSortWorkerLeads(
        leads: leads,
        search: 'islamabad',
        filters: const WorkerLeadFilters(),
        sort: WorkerLeadSort.recommended,
        now: now,
      ).single.id,
      'urgent-near',
    );
    expect(
      filterAndSortWorkerLeads(
        leads: leads,
        search: '',
        filters: const WorkerLeadFilters(
          urgency: 'Urgent',
          minimumBudget: 5000,
          maximumBudget: 10000,
          maximumDistanceKm: 5,
          postedWithin: WorkerLeadPostedWithin.day,
        ),
        sort: WorkerLeadSort.newest,
        now: now,
      ).single.id,
      'urgent-near',
    );
    for (final sort in WorkerLeadSort.values) {
      final sorted = filterAndSortWorkerLeads(
        leads: leads,
        search: '',
        filters: const WorkerLeadFilters(),
        sort: sort,
        now: now,
      );
      expect(sorted, hasLength(2));
    }
    expect(
      filterAndSortWorkerLeads(
        leads: leads,
        search: '',
        filters: const WorkerLeadFilters(),
        sort: WorkerLeadSort.highestBudget,
      ).first.id,
      'urgent-near',
    );
    expect(
      filterAndSortWorkerLeads(
        leads: leads,
        search: '',
        filters: const WorkerLeadFilters(),
        sort: WorkerLeadSort.lowestBudget,
      ).first.id,
      'normal-far',
    );
    expect(
      filterAndSortWorkerLeads(
        leads: leads,
        search: '',
        filters: const WorkerLeadFilters(),
        sort: WorkerLeadSort.nearest,
      ).first.id,
      'urgent-near',
    );
  });

  test(
    'acceptance plan preserves one-credit and accepted lifecycle contract',
    () {
      final plan = planWorkerLeadAcceptance(
        workerId: 'worker-1',
        workerData: _worker().data,
        requestId: 'lead-1',
        requestData: _lead(id: 'lead-1').data,
      );
      expect(plan.balanceBefore, 5);
      expect(plan.balanceAfter, 4);
      expect(plan.workerId, 'worker-1');
      expect(plan.nextStatus, 'accepted');

      expect(
        () => planWorkerLeadAcceptance(
          workerId: 'worker-1',
          workerData: _worker(credits: 0).data,
          requestId: 'lead-1',
          requestData: _lead(id: 'lead-1').data,
        ),
        throwsA(
          isA<WorkerLeadAcceptanceException>().having(
            (error) => error.failure,
            'failure',
            WorkerLeadAcceptanceFailure.insufficientCredits,
          ),
        ),
      );
      for (final changed in [
        _lead(id: 'lead-1', status: 'cancelled'),
        _lead(id: 'lead-1', status: 'accepted', workerId: 'worker-2'),
      ]) {
        expect(
          () => planWorkerLeadAcceptance(
            workerId: 'worker-1',
            workerData: _worker().data,
            requestId: changed.id,
            requestData: changed.data,
          ),
          throwsA(isA<WorkerLeadAcceptanceException>()),
        );
      }
      expect(
        () => planWorkerLeadAcceptance(
          workerId: 'worker-1',
          workerData: _worker(verification: 'pending').data,
          requestId: 'lead-1',
          requestData: _lead(id: 'lead-1').data,
        ),
        throwsA(
          isA<WorkerLeadAcceptanceException>().having(
            (error) => error.failure,
            'failure',
            WorkerLeadAcceptanceFailure.workerIneligible,
          ),
        ),
      );
    },
  );

  testWidgets(
    'Leads supports search, filters, sorting and empty states at 390',
    (tester) async {
      _size(tester, const Size(390, 844));
      final repo = _FakeWorkerLeadsRepository(
        worker: _worker(),
        leads: [
          _lead(
            id: 'one',
            title: 'Bedroom AC not cooling',
            urgency: 'Urgent',
            budget: '9000',
            distance: 2,
            customer: const WorkerLeadCustomer(
              id: 'c1',
              name: 'Ayesha Khan',
              city: 'Islamabad',
            ),
          ),
          _lead(
            id: 'two',
            title: 'Office air conditioner service',
            urgency: 'Normal',
            budget: '3000',
            distance: 14,
          ),
        ],
      );
      await tester.pumpWidget(_app(WorkerLeadsScreen(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('Leads'), findsOneWidget);
      expect(find.text('Posted budget'), findsNWidgets(2));
      expect(find.text('Ayesha'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('worker-lead-search')),
        'office',
      );
      await tester.pump();
      expect(find.text('Bedroom AC not cooling'), findsNothing);
      expect(find.text('Office air conditioner service'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('worker-lead-search')),
        '',
      );

      await tester.tap(find.byKey(const ValueKey('worker-lead-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Urgent'));
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text('Bedroom AC not cooling'), findsOneWidget);
      expect(find.text('Office air conditioner service'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('worker-lead-sort')));
      await tester.pumpAndSettle();
      expect(find.text('Highest posted budget'), findsOneWidget);
      Navigator.pop(tester.element(find.text('Sort leads')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('List and map preserve filters and use only valid map points', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    final repo = _FakeWorkerLeadsRepository(
      worker: _worker(),
      leads: [
        _lead(id: 'valid', lat: 33.6844, lng: 73.0479),
        _lead(id: 'missing'),
        _lead(id: 'invalid', lat: 120, lng: 400),
      ],
    );
    await tester.pumpWidget(_app(WorkerLeadsScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('worker-lead-search')),
      'AC',
    );
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    final map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(
      map.markers.where((marker) => marker.markerId.value != 'current-worker'),
      hasLength(1),
    );
    expect(
      map.markers.any((marker) => marker.markerId.value == 'valid'),
      isTrue,
    );
    expect(find.textContaining('1 of 3 leads'), findsOneWidget);
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('worker-lead-search')))
          .controller
          ?.text,
      'AC',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Lead detail confirms credit spend and prevents double acceptance',
    (tester) async {
      _size(tester, const Size(320, 720));
      final acceptance = Completer<void>();
      final repo = _FakeWorkerLeadsRepository(
        worker: _worker(credits: 8),
        leads: [_lead(id: 'detail', budget: '5000')],
        acceptance: acceptance,
      );
      var accepted = 0;
      await tester.pumpWidget(
        _app(
          WorkerLeadDetailScreen(
            requestId: 'detail',
            repository: repo,
            onAccepted: (_) => accepted++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'initial detail layout');
      expect(find.text('Posted budget'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Lead cost'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull, reason: 'scrolled detail layout');
      expect(find.text('Lead cost'), findsOneWidget);
      expect(find.text('1 credit'), findsOneWidget);
      expect(
        find.textContaining('exact service address is kept private'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('accept-lead')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'confirmation layout');
      expect(find.text('Accept this lead?'), findsOneWidget);
      expect(find.text('8 credits → 7 credits'), findsOneWidget);
      expect(find.textContaining('not guaranteed earnings'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-accept-lead')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'accepting layout');
      expect(repo.acceptCalls, 1);
      expect(find.text('Accepting lead…'), findsOneWidget);
      acceptance.complete();
      await tester.pumpAndSettle();
      expect(repo.acceptCalls, 1);
      expect(accepted, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zero credits and ineligible workers get truthful actions', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    var creditsOpened = 0;
    final zeroRepo = _FakeWorkerLeadsRepository(
      worker: _worker(credits: 0),
      leads: [_lead(id: 'zero')],
    );
    await tester.pumpWidget(
      _app(
        WorkerLeadDetailScreen(
          key: const ValueKey('zero-credit-detail'),
          requestId: 'zero',
          repository: zeroRepo,
          onGetCredits: () => creditsOpened++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get credits'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('get-lead-credits')));
    expect(creditsOpened, 1);

    final pendingRepo = _FakeWorkerLeadsRepository(
      worker: _worker(verification: 'pending'),
      leads: [_lead(id: 'pending')],
    );
    await tester.pumpWidget(
      _app(
        WorkerLeadDetailScreen(
          key: const ValueKey('pending-detail'),
          requestId: 'pending',
          repository: pendingRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verification under review'), findsOneWidget);
    expect(find.text('Lead unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('acceptance failures show professional messages', (tester) async {
    _size(tester, const Size(390, 844));
    final repo = _FakeWorkerLeadsRepository(
      worker: _worker(),
      leads: [_lead(id: 'failure')],
      acceptError: const WorkerLeadAcceptanceException(
        WorkerLeadAcceptanceFailure.unavailable,
        'This lead was changed or accepted by another worker.',
      ),
    );
    await tester.pumpWidget(
      _app(WorkerLeadDetailScreen(requestId: 'failure', repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('accept-lead')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-accept-lead')));
    await tester.pumpAndSettle();
    expect(
      find.text('This lead was changed or accepted by another worker.'),
      findsOneWidget,
    );
    expect(find.textContaining('FirebaseException'), findsNothing);
  });
}

WorkerHomeProfile _worker({int credits = 5, String verification = 'approved'}) {
  return WorkerHomeProfile(
    uid: 'worker-1',
    data: {
      'role': 'worker',
      'name': 'Muhammad Ahmed With A Long Worker Display Name',
      'skill': 'AC Repair',
      'profileCompleted': true,
      'identityVerificationStatus': verification,
      'canAcceptJobs': true,
      'accountStatus': 'active',
      'credits': credits,
      'lat': 33.6938,
      'lng': 73.0652,
    },
  );
}

WorkerLead _lead({
  required String id,
  String title = 'AC service request',
  String category = 'AC Repair',
  String status = 'searching',
  String? workerId,
  String urgency = 'Normal',
  String budget = '5000',
  double? lat,
  double? lng,
  double? distance,
  DateTime? createdAt,
  List<String> images = const [],
  WorkerLeadCustomer? customer,
}) {
  return WorkerLead(
    id: id,
    data: {
      'customerId': 'customer-$id',
      'title': title,
      'description': 'The unit is making noise and needs a careful inspection.',
      'category': category,
      'status': status,
      'workerId': workerId,
      'urgency': urgency,
      'budget': budget,
      'location': 'House 10, Private Street',
      'latitude': lat,
      'longitude': lng,
      'createdAt': createdAt ?? DateTime(2026, 9, 3, 10),
      'imageUrls': images,
    },
    customer: customer,
    distanceKm: distance,
  );
}

class _FakeWorkerLeadsRepository implements WorkerLeadsRepository {
  _FakeWorkerLeadsRepository({
    required this.worker,
    required this.leads,
    this.acceptance,
    this.acceptError,
  });

  final WorkerHomeProfile worker;
  final List<WorkerLead> leads;
  final Completer<void>? acceptance;
  final Object? acceptError;
  int acceptCalls = 0;

  @override
  String get currentWorkerId => worker.uid;

  @override
  Future<void> acceptLead(String requestId) async {
    acceptCalls++;
    if (acceptError != null) throw acceptError!;
    await acceptance?.future;
  }

  @override
  Future<void> refresh(WorkerHomeProfile worker) async {}

  @override
  Stream<WorkerLead?> watchLead(String requestId, WorkerHomeProfile worker) =>
      Stream.value(leads.where((lead) => lead.id == requestId).firstOrNull);

  @override
  Stream<List<WorkerLead>> watchLeads(WorkerHomeProfile worker) =>
      Stream.value(leads);

  @override
  Stream<WorkerHomeProfile> watchWorker() => Stream.value(worker);
}

Widget _app(Widget child) => MaterialApp(
  theme: SkillNovaTheme.light,
  darkTheme: SkillNovaTheme.dark,
  home: WorkerNavigationScope(child: child),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
