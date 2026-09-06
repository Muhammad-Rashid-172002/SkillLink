import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_detail_screen.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_job_models.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_repository.dart';
import 'package:skill_link/screens/worker_screens/jobs/worker_jobs_screen.dart';

void main() {
  group('Worker Job status and model adapters', () {
    test('normalizes only supported lifecycle and compatibility values', () {
      expect(workerJobStatusOf('accepted').status, WorkerJobStatus.accepted);
      for (final value in ['on_the_way', 'on the way', 'ontheway']) {
        expect(workerJobStatusOf(value).status, WorkerJobStatus.onTheWay);
      }
      for (final value in ['in_progress', 'in progress', 'started']) {
        expect(workerJobStatusOf(value).status, WorkerJobStatus.inProgress);
      }
      for (final value in ['cancelled', 'canceled', 'rejected']) {
        expect(workerJobStatusOf(value).status, WorkerJobStatus.cancelled);
      }
      expect(workerJobStatusOf('arrived').status, WorkerJobStatus.unknown);
      expect(workerJobStatusOf('arrived').label, 'Job status unavailable');
    });

    test('adapts reliable fields, bounded images, coordinates, and review', () {
      final job = WorkerJob(
        id: 'job-1',
        data: {
          'workerId': 'worker-1',
          'customerId': 'customer-1',
          'status': 'completed',
          'title': 'Repair a very old air conditioner',
          'category': 'AC technician',
          'budget': '5000',
          'location': 'House 10, Street 5',
          'notes': 'Bring a ladder',
          'latitude': 33.7,
          'longitude': 73.1,
          'completedAt': DateTime(2026, 8, 1),
          'imageUrls': List.generate(8, (index) => 'image-$index'),
        },
        customer: const WorkerJobCustomer(
          id: 'customer-1',
          name: 'Alexandra Long Customer Name',
          city: 'Islamabad',
          phone: '03001234567',
        ),
        review: const WorkerJobReview(rating: 4.5, text: 'Excellent work'),
      );
      expect(job.imageUrls, hasLength(5));
      expect(job.serviceCoordinate?.latitude, 33.7);
      expect(job.serviceArea, 'Islamabad');
      expect(job.relevantDate, DateTime(2026, 8, 1));
      expect(formatWorkerJobBudget(job.budget), 'Rs 5,000');
      expect(job.review?.text, 'Excellent work');
    });

    test(
      'scopes jobs by assigned worker/group and declares bounded queries',
      () {
        final own = _job(status: 'accepted');
        final other = _job(status: 'accepted', workerId: 'worker-2');
        final completed = _job(status: 'completed');
        expect(
          isWorkerJobInGroup(own, 'worker-1', WorkerJobGroup.active),
          isTrue,
        );
        expect(
          isWorkerJobInGroup(other, 'worker-1', WorkerJobGroup.active),
          isFalse,
        );
        expect(
          isWorkerJobInGroup(completed, 'worker-1', WorkerJobGroup.active),
          isFalse,
        );
        expect(workerJobQueryLimits[WorkerJobGroup.active], 20);
        expect(workerJobQueryLimits[WorkerJobGroup.completed], 50);
        expect(workerJobQueryLimits[WorkerJobGroup.cancelled], 30);
        expect(
          workerJobQueryStatuses(WorkerJobGroup.active),
          contains('started'),
        );
        expect(workerJobPrimaryAction(WorkerJobStatus.accepted), 'On my way');
        expect(workerJobPrimaryAction(WorkerJobStatus.onTheWay), 'Start job');
        expect(
          workerJobPrimaryAction(WorkerJobStatus.inProgress),
          'Complete job',
        );
        expect(workerJobPrimaryAction(WorkerJobStatus.completed), isEmpty);
      },
    );

    test('searches only service, customer, and service-area data', () {
      final jobs = [
        _job(title: 'Fix wiring', category: 'Electrician'),
        _job(
          id: 'job-2',
          title: 'Repair tap',
          category: 'Plumber',
          customer: const WorkerJobCustomer(
            id: 'customer-2',
            name: 'Mina Customer',
            city: 'Lahore',
          ),
        ),
      ];
      expect(searchWorkerJobs(jobs, 'electric'), [jobs.first]);
      expect(searchWorkerJobs(jobs, 'mina'), [jobs.last]);
      expect(searchWorkerJobs(jobs, 'lahore'), [jobs.last]);
      expect(searchWorkerJobs(jobs, 'nobody'), isEmpty);
    });
  });

  group('Worker Job lifecycle safety', () {
    test('allows each immediate canonical transition', () {
      final accepted = planWorkerJobTransition(
        authenticatedWorkerId: 'worker-1',
        requestData: _jobData(status: 'accepted'),
        expectedStatus: WorkerJobStatus.accepted,
        requestedStatus: WorkerJobStatus.onTheWay,
      );
      expect(accepted.firestoreValue, 'on_the_way');

      final travelling = planWorkerJobTransition(
        authenticatedWorkerId: 'worker-1',
        requestData: _jobData(status: 'on the way'),
        expectedStatus: WorkerJobStatus.onTheWay,
        requestedStatus: WorkerJobStatus.inProgress,
      );
      expect(travelling.firestoreValue, 'in_progress');

      final started = planWorkerJobTransition(
        authenticatedWorkerId: 'worker-1',
        requestData: _jobData(status: 'started'),
        expectedStatus: WorkerJobStatus.inProgress,
        requestedStatus: WorkerJobStatus.completed,
      );
      expect(started.firestoreValue, 'completed');
    });

    test('rejects status skipping and terminal progression', () {
      expect(
        () => planWorkerJobTransition(
          authenticatedWorkerId: 'worker-1',
          requestData: _jobData(status: 'accepted'),
          expectedStatus: WorkerJobStatus.accepted,
          requestedStatus: WorkerJobStatus.inProgress,
        ),
        throwsA(
          isA<WorkerJobTransitionException>().having(
            (error) => error.failure,
            'failure',
            WorkerJobTransitionFailure.invalid,
          ),
        ),
      );
      expect(
        () => planWorkerJobTransition(
          authenticatedWorkerId: 'worker-1',
          requestData: _jobData(status: 'completed'),
          expectedStatus: WorkerJobStatus.completed,
          requestedStatus: WorkerJobStatus.completed,
        ),
        throwsA(isA<WorkerJobTransitionException>()),
      );
    });

    test('rejects wrong worker, missing request, and stale status', () {
      expect(
        () => planWorkerJobTransition(
          authenticatedWorkerId: 'worker-2',
          requestData: _jobData(status: 'accepted'),
          expectedStatus: WorkerJobStatus.accepted,
          requestedStatus: WorkerJobStatus.onTheWay,
        ),
        throwsA(
          isA<WorkerJobTransitionException>().having(
            (error) => error.failure,
            'failure',
            WorkerJobTransitionFailure.wrongWorker,
          ),
        ),
      );
      expect(
        () => planWorkerJobTransition(
          authenticatedWorkerId: 'worker-1',
          requestData: null,
          expectedStatus: WorkerJobStatus.accepted,
          requestedStatus: WorkerJobStatus.onTheWay,
        ),
        throwsA(isA<WorkerJobTransitionException>()),
      );
      expect(
        () => planWorkerJobTransition(
          authenticatedWorkerId: 'worker-1',
          requestData: _jobData(status: 'in_progress'),
          expectedStatus: WorkerJobStatus.onTheWay,
          requestedStatus: WorkerJobStatus.inProgress,
        ),
        throwsA(
          isA<WorkerJobTransitionException>().having(
            (error) => error.failure,
            'failure',
            WorkerJobTransitionFailure.stale,
          ),
        ),
      );
    });
  });

  group('Worker Jobs screen', () {
    testWidgets(
      'shows active jobs and preserves search across tabs at 390x844',
      (tester) async {
        await _setSize(tester, const Size(390, 844));
        final active = [
          _job(title: 'Fix wiring', category: 'Electrician'),
          _job(id: 'job-2', title: 'Install fan', category: 'Electrician'),
        ];
        final completed = [
          _job(id: 'job-3', status: 'completed', title: 'Fix wiring'),
        ];
        final repository = _FakeWorkerJobsRepository(
          groups: {
            WorkerJobGroup.active: active,
            WorkerJobGroup.completed: completed,
            WorkerJobGroup.cancelled: const [],
          },
        );
        await tester.pumpWidget(
          _app(WorkerJobsScreen(repository: repository, embedded: true)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fix wiring'), findsOneWidget);
        expect(find.text('Install fan'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('worker-jobs-search')),
          'wiring',
        );
        await tester.pump();
        expect(find.text('Install fan'), findsNothing);
        await tester.tap(find.text('Completed'));
        await tester.pumpAndSettle();
        expect(find.text('Fix wiring'), findsOneWidget);
        expect(find.text('No review yet'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller?.text,
          'wiring',
        );
      },
    );

    testWidgets('shows dark compact empty and error states without overflow', (
      tester,
    ) async {
      await _setSize(tester, const Size(320, 720));
      final empty = _FakeWorkerJobsRepository();
      await tester.pumpWidget(
        _app(
          WorkerJobsScreen(repository: empty, embedded: true),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No active jobs'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _app(
          WorkerJobsScreen(
            key: const ValueKey('error-jobs-screen'),
            repository: _FakeWorkerJobsRepository(
              errorGroups: {WorkerJobGroup.active},
            ),
            embedded: true,
          ),
          mode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load active jobs'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders completed review and real cancellation reason', (
      tester,
    ) async {
      await _setSize(tester, const Size(390, 844));
      final repository = _FakeWorkerJobsRepository(
        groups: {
          WorkerJobGroup.completed: [
            _job(
              status: 'completed',
              review: const WorkerJobReview(rating: 4.8, text: 'Great'),
            ),
          ],
          WorkerJobGroup.cancelled: [
            _job(
              id: 'cancelled-job',
              status: 'cancelled',
              extra: {'cancellationReason': 'Customer changed plans'},
            ),
          ],
        },
      );
      await tester.pumpWidget(
        _app(
          WorkerJobsScreen(
            repository: repository,
            embedded: true,
            initialGroup: WorkerJobGroup.completed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4.8 customer review'), findsOneWidget);
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();
      expect(find.text('Reason: Customer changed plans'), findsOneWidget);
    });
  });

  group('Worker Job Detail V2', () {
    testWidgets('handles missing request and missing customer safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          WorkerJobDetailV2Screen(
            requestId: 'missing',
            repository: _FakeWorkerJobsRepository(),
            enableLocationSharing: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Job not found'), findsOneWidget);

      final missingCustomer = WorkerJob(
        id: 'job-1',
        data: _jobData(status: 'accepted'),
      );
      await tester.pumpWidget(
        _app(
          WorkerJobDetailV2Screen(
            key: const ValueKey('missing-customer-job'),
            requestId: 'job-1',
            repository: _FakeWorkerJobsRepository(detail: missingCustomer),
            enableLocationSharing: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Customer information unavailable'), findsOneWidget);
      expect(find.text('Phone unavailable'), findsOneWidget);
    });

    testWidgets('shows bounded request images and handles broken media', (
      tester,
    ) async {
      final job = _job(
        extra: {
          'imageUrls': List.generate(
            7,
            (index) => 'https://invalid.example/image-$index.jpg',
          ),
        },
      );
      await tester.pumpWidget(
        _app(
          WorkerJobDetailV2Screen(
            requestId: job.id,
            repository: _FakeWorkerJobsRepository(detail: job),
            enableLocationSharing: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Request images'),
        find.byKey(const ValueKey('worker-job-detail-scroll')),
        const Offset(0, -220),
      );
      expect(find.text('Request images'), findsOneWidget);
      expect(job.imageUrls, hasLength(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'shows truthful accepted job data and unavailable states at 320',
      (tester) async {
        await _setSize(tester, const Size(320, 720));
        final job = _job(
          title:
              'A very long service title that remains readable on small phones',
          extra: {
            'description': List.filled(
              8,
              'A long customer description',
            ).join(' '),
            'budget': '999999999',
            'location': 'A long but real accepted service address, Islamabad',
          },
          customer: const WorkerJobCustomer(
            id: 'customer-1',
            name: 'A Customer With An Exceptionally Long Name',
            city: 'Islamabad',
          ),
        );
        await tester.pumpWidget(
          _app(
            WorkerJobDetailV2Screen(
              requestId: job.id,
              repository: _FakeWorkerJobsRepository(detail: job),
              enableLocationSharing: false,
            ),
            mode: ThemeMode.dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Accepted'), findsWidgets);
        await tester.dragUntilVisible(
          find.text('Posted budget'),
          find.byKey(const ValueKey('worker-job-detail-scroll')),
          const Offset(0, -220),
        );
        expect(find.text('Posted budget'), findsOneWidget);
        expect(find.text('Rs 999,999,999'), findsOneWidget);
        expect(find.text('Phone unavailable'), findsOneWidget);
        await tester.dragUntilVisible(
          find.byKey(const ValueKey('worker-job-no-map')),
          find.byKey(const ValueKey('worker-job-detail-scroll')),
          const Offset(0, -220),
        );
        expect(find.byKey(const ValueKey('worker-job-no-map')), findsOneWidget);
        expect(find.text('On my way'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows valid real markers without route or ETA', (
      tester,
    ) async {
      await _setSize(tester, const Size(390, 844));
      final job = _job(extra: {'latitude': 33.7, 'longitude': 73.1});
      await tester.pumpWidget(
        _app(
          WorkerJobDetailV2Screen(
            requestId: job.id,
            repository: _FakeWorkerJobsRepository(
              detail: job,
              workerCoordinate: const WorkerCoordinate(33.69, 73.09),
            ),
            enableLocationSharing: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('worker-job-map')),
        find.byKey(const ValueKey('worker-job-detail-scroll')),
        const Offset(0, -250),
      );
      final map = tester.widget<GoogleMap>(
        find.byKey(const ValueKey('worker-job-map')),
      );
      expect(map.markers.map((marker) => marker.markerId.value), {
        'service-location',
        'worker-location',
      });
      expect(
        find.text('No route or arrival time is calculated.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'message and legitimate phone actions use current job customer',
      (tester) async {
        var messages = 0;
        String? called;
        final job = _job(
          customer: const WorkerJobCustomer(
            id: 'customer-1',
            name: 'Sara Customer',
            phone: '03001234567',
          ),
        );
        await tester.pumpWidget(
          _app(
            WorkerJobDetailV2Screen(
              requestId: job.id,
              repository: _FakeWorkerJobsRepository(detail: job),
              enableLocationSharing: false,
              onMessage: (_) async => messages++,
              onCall: (phone) async => called = phone,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Message'));
        await tester.pump();
        await tester.tap(find.text('Call'));
        await tester.pump();
        expect(messages, 1);
        expect(called, '03001234567');
      },
    );

    testWidgets('chat failure hides raw backend details', (tester) async {
      final job = _job();
      await tester.pumpWidget(
        _app(
          WorkerJobDetailV2Screen(
            requestId: job.id,
            repository: _FakeWorkerJobsRepository(detail: job, chatError: true),
            enableLocationSharing: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(
        find.text('Messaging is unavailable for this job.'),
        findsOneWidget,
      );
      expect(find.textContaining('firebase'), findsNothing);
    });

    testWidgets('double tap starts only one status mutation', (tester) async {
      final completer = Completer<void>();
      final repository = _FakeWorkerJobsRepository(
        detail: _job(status: 'accepted'),
        transitionCompleter: completer,
      );
      await tester.pumpWidget(
        _app(
          WorkerJobDetailV2Screen(
            requestId: 'job-1',
            repository: repository,
            enableLocationSharing: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('On my way'));
      await tester.tap(find.text('On my way'));
      await tester.pump();
      expect(repository.transitionCalls, 1);
      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'completion requires confirmation and keeps payout wording honest',
      (tester) async {
        await _setSize(tester, const Size(320, 720));
        final repository = _FakeWorkerJobsRepository(
          detail: _job(status: 'in_progress'),
        );
        await tester.pumpWidget(
          _app(
            WorkerJobDetailV2Screen(
              requestId: 'job-1',
              repository: repository,
              enableLocationSharing: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Complete job'));
        await tester.pumpAndSettle();
        expect(find.text('Complete this job?'), findsOneWidget);
        expect(
          find.textContaining('not a confirmed payout or payment'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('confirm-complete-job')));
        await tester.pumpAndSettle();
        expect(repository.transitionCalls, 1);
        expect(repository.lastExpected, WorkerJobStatus.inProgress);
        expect(repository.lastNext, WorkerJobStatus.completed);
      },
    );

    testWidgets(
      'shows real review, no-review state, SOS entry, and safe failures',
      (tester) async {
        final completed = _job(
          status: 'completed',
          review: const WorkerJobReview(
            rating: 5,
            text: 'Careful professional',
          ),
        );
        await tester.pumpWidget(
          _app(
            WorkerJobDetailV2Screen(
              requestId: completed.id,
              repository: _FakeWorkerJobsRepository(detail: completed),
              enableLocationSharing: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.dragUntilVisible(
          find.text('Careful professional'),
          find.byKey(const ValueKey('worker-job-detail-scroll')),
          const Offset(0, -250),
        );
        expect(find.text('5.0'), findsOneWidget);
        expect(find.text('Careful professional'), findsOneWidget);

        final active = _job(status: 'on_the_way');
        await tester.pumpWidget(
          _app(
            WorkerJobDetailV2Screen(
              key: const ValueKey('active-sos-job'),
              requestId: active.id,
              repository: _FakeWorkerJobsRepository(
                detail: active,
                transitionError: true,
                locationResult: WorkerLocationUpdateResult.permissionDenied,
              ),
              enableLocationSharing: true,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.dragUntilVisible(
          find.text('Send SOS'),
          find.byKey(const ValueKey('worker-job-detail-scroll')),
          const Offset(0, -250),
        );
        expect(find.text('Send SOS'), findsOneWidget);
        expect(
          find.textContaining('does not automatically contact'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Location permission is denied'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'mutation failure displays a safe message and leaves action usable',
      (tester) async {
        final repository = _FakeWorkerJobsRepository(
          detail: _job(status: 'accepted'),
          transitionError: true,
        );
        await tester.pumpWidget(
          _app(
            WorkerJobDetailV2Screen(
              requestId: 'job-1',
              repository: repository,
              enableLocationSharing: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('On my way'));
        await tester.pumpAndSettle();
        expect(
          find.text('The job could not be updated. Please try again.'),
          findsOneWidget,
        );
        expect(find.textContaining('firebase'), findsNothing);
        expect(repository.transitionCalls, 1);
      },
    );
  });
}

Map<String, dynamic> _jobData({
  String status = 'accepted',
  String workerId = 'worker-1',
  Map<String, dynamic> extra = const {},
}) {
  return {
    'workerId': workerId,
    'customerId': 'customer-1',
    'status': status,
    'title': 'Fix wiring',
    'category': 'Electrician',
    'budget': '5000',
    'createdAt': DateTime(2026, 8, 1),
    ...extra,
  };
}

WorkerJob _job({
  String id = 'job-1',
  String status = 'accepted',
  String workerId = 'worker-1',
  String title = 'Fix wiring',
  String category = 'Electrician',
  WorkerJobCustomer? customer,
  WorkerJobReview? review,
  Map<String, dynamic> extra = const {},
}) {
  return WorkerJob(
    id: id,
    data: _jobData(
      status: status,
      workerId: workerId,
      extra: {'title': title, 'category': category, ...extra},
    ),
    customer:
        customer ??
        const WorkerJobCustomer(
          id: 'customer-1',
          name: 'Sara Customer',
          city: 'Islamabad',
        ),
    review: review,
  );
}

Widget _app(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: SkillNovaTheme.light,
    darkTheme: SkillNovaTheme.dark,
    themeMode: mode,
    home: child,
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _FakeWorkerJobsRepository implements WorkerJobsRepository {
  _FakeWorkerJobsRepository({
    Map<WorkerJobGroup, List<WorkerJob>> groups = const {},
    Set<WorkerJobGroup> errorGroups = const {},
    this.detail,
    this.workerCoordinate,
    this.transitionCompleter,
    this.transitionError = false,
    this.chatError = false,
    this.locationResult = WorkerLocationUpdateResult.shared,
  }) : _groups = groups,
       _errorGroups = errorGroups;

  final Map<WorkerJobGroup, List<WorkerJob>> _groups;
  final Set<WorkerJobGroup> _errorGroups;
  final WorkerJob? detail;
  final WorkerCoordinate? workerCoordinate;
  final Completer<void>? transitionCompleter;
  final bool transitionError;
  final bool chatError;
  final WorkerLocationUpdateResult locationResult;
  int transitionCalls = 0;
  WorkerJobStatus? lastExpected;
  WorkerJobStatus? lastNext;

  @override
  String? get currentWorkerId => 'worker-1';

  @override
  Future<void> refreshJobs(WorkerJobGroup group) async {}

  @override
  Future<WorkerJobChatDestination> resolveChat(WorkerJob job) async {
    if (chatError) {
      throw const WorkerJobTransitionException(
        WorkerJobTransitionFailure.stale,
        'Messaging is unavailable for this job.',
      );
    }
    return WorkerJobChatDestination(
      chatId: 'request-${job.id}',
      customerId: job.customerId,
      customerName: job.customer?.name ?? 'Customer',
      service: job.category,
    );
  }

  @override
  Future<WorkerLocationUpdateResult> shareLocation(String requestId) async {
    return locationResult;
  }

  @override
  Future<void> transitionJob({
    required String requestId,
    required WorkerJobStatus expectedStatus,
    required WorkerJobStatus nextStatus,
  }) async {
    transitionCalls++;
    lastExpected = expectedStatus;
    lastNext = nextStatus;
    if (transitionError) {
      throw const WorkerJobTransitionException(
        WorkerJobTransitionFailure.network,
        'The job could not be updated. Please try again.',
      );
    }
    await transitionCompleter?.future;
  }

  @override
  Stream<WorkerJob?> watchJob(String requestId) => Stream.value(detail);

  @override
  Stream<List<WorkerJob>> watchJobs(WorkerJobGroup group) {
    if (_errorGroups.contains(group)) {
      return Stream.error(Exception('firebase internal details'));
    }
    return Stream.value(_groups[group] ?? const []);
  }

  @override
  Stream<WorkerCoordinate?> watchWorkerCoordinate() {
    return Stream.value(workerCoordinate);
  }
}
