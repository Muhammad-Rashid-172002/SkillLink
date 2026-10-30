import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skilllink_admin/screens/admin_user_detail_screen.dart';
import 'package:skilllink_admin/screens/admin_users_screen.dart';
import 'package:skilllink_admin/services/ser_management_service.dart';
import 'package:skilllink_admin/services/verification_management_service.dart';

final now = DateTime(2026, 10, 30, 12);

ManagedUser user(
  String id, {
  String role = 'customer',
  String name = '',
  String email = '',
  String phone = '',
  bool emailVerified = false,
  bool phoneVerified = false,
  String? identity,
  String status = 'active',
  bool complete = true,
  int daysAgo = 30,
  Map<String, dynamic> extra = const {},
}) => ManagedUser.fromMap(id, {
  'role': role,
  'name': name,
  'email': email,
  'phoneNumber': phone,
  'emailVerified': emailVerified,
  'phoneVerified': phoneVerified,
  'identityVerificationStatus': ?identity,
  'accountStatus': status,
  'profileCompleted': complete,
  'createdAt': now.subtract(Duration(days: daysAgo)),
  ...extra,
});

List<ManagedUser> sampleUsers() => [
  user(
    'c_ok',
    name: 'Ayesha Verified',
    email: 'ayesha@test.pk',
    phone: '+923001111111',
    emailVerified: true,
    phoneVerified: true,
    daysAgo: 2,
  ),
  user(
    'c_new',
    name: 'Bilal Unverified',
    email: 'bilal@test.pk',
    emailVerified: true,
    complete: false,
    daysAgo: 1,
  ),
  user(
    'w_ok',
    role: 'worker',
    name: 'Kamran Approved',
    email: 'kamran@test.pk',
    phone: '+923002222222',
    emailVerified: true,
    phoneVerified: true,
    identity: 'approved',
    daysAgo: 60,
  ),
  user(
    'w_pending',
    role: 'worker',
    name: 'Danish Pending',
    phone: '+923003333333',
    phoneVerified: true,
    identity: 'pending',
    daysAgo: 5,
  ),
  user(
    'w_rejected',
    role: 'worker',
    name: 'Faraz Rejected',
    email: 'faraz@test.pk',
    identity: 'rejected',
    daysAgo: 90,
  ),
  user(
    'w_legacy',
    role: 'worker',
    name: 'Legacy Flag',
    email: 'legacy@test.pk',
    // Old client-writable flag must not count as verified.
    extra: {'isVerified': true, 'verified': true},
    daysAgo: 400,
  ),
  user(
    'c_banned',
    name: 'Spam Account',
    email: 'spam@test.pk',
    status: 'suspended',
    daysAgo: 10,
  ),
  user('admin_me', name: 'Me Admin', email: 'me@skillnova.test'),
];

class FakeGateway implements UserAdminGateway {
  FakeGateway(List<ManagedUser> users) {
    _users = [...users];
    _controller.add(_users);
  }

  late List<ManagedUser> _users;
  final _controller = StreamController<List<ManagedUser>>.broadcast();
  final deleted = <(String, DeletionReason, String)>[];
  final bulkCalls = <List<String>>[];
  final statusCalls = <(String, bool, String)>[];
  Set<String> failing = {};
  VerificationDetails? verification;
  bool approved = false;

  @override
  String? currentAdminUid = 'admin_me';

  @override
  Stream<List<ManagedUser>> watchUsers() async* {
    yield _users;
    yield* _controller.stream;
  }

  void _remove(String uid) {
    _users = _users.where((u) => u.id != uid).toList();
    _controller.add(_users);
  }

  @override
  Future<DeletionOutcome> deleteUser(
    String uid, {
    required DeletionReason reason,
    String detail = '',
  }) async {
    deleted.add((uid, reason, detail));
    if (failing.contains(uid)) {
      return DeletionOutcome(
        uid: uid,
        status: 'failed',
        message: 'This account has 1 active job.',
      );
    }
    _remove(uid);
    return DeletionOutcome(uid: uid, status: 'completed');
  }

  @override
  Future<BulkDeletionOutcome> deleteUsers(
    List<String> uids, {
    required DeletionReason reason,
    String detail = '',
    Map<String, DeletionReason> perUserReasons = const {},
  }) async {
    expect(
      uids.length,
      lessThanOrEqualTo(UserManagementService.maxBulkPerCall),
    );
    bulkCalls.add(uids);
    final results = <DeletionOutcome>[];
    for (final uid in uids) {
      results.add(await deleteUser(uid, reason: perUserReasons[uid] ?? reason));
    }
    return BulkDeletionOutcome(results);
  }

  @override
  Future<void> setAccountStatus(
    String uid, {
    required bool suspended,
    String reason = '',
  }) async {
    statusCalls.add((uid, suspended, reason));
  }

  @override
  Future<VerificationDetails?> loadVerification(String uid) async =>
      verification;

  @override
  Future<String?> documentUrl(String storagePath) async => null;

  @override
  Future<void> approveVerification(VerificationRequestModel request) async {
    approved = true;
  }

  @override
  Future<void> rejectVerification(
    VerificationRequestModel request,
    String reason,
  ) async {}
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeGateway gateway, {
  // The test font is wider than Inter, so the desktop table needs more room
  // here than in a real 1440 px browser window.
  Size size = const Size(1800, 2600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminUsersScreen(gateway: gateway, now: () => now),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String resultCount(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('result-count'))).data!;

void main() {
  group('verification classification', () {
    test('users are verified only by the platform, never by existing', () {
      final byId = {for (final u in sampleUsers()) u.id: u};
      expect(byId['c_ok']!.verification, UserVerification.verified);
      expect(byId['c_new']!.verification, UserVerification.unverified);
      expect(byId['w_ok']!.verification, UserVerification.verified);
      expect(byId['w_pending']!.verification, UserVerification.pending);
      expect(byId['w_rejected']!.verification, UserVerification.rejected);
      expect(
        byId['w_legacy']!.verification,
        UserVerification.unverified,
        reason: 'legacy isVerified flags are ignored',
      );
      final bare = ManagedUser.fromMap('x', const {'role': 'worker'});
      expect(bare.verification, UserVerification.unverified);
      expect(bare.identityStatusLabel, 'Not submitted');
      expect(
        ManagedUser.fromMap('y', const {}).verification,
        UserVerification.unverified,
      );
    });

    test('stats count every bucket and recent sign-ups', () {
      final stats = UserStats.of(sampleUsers(), now: now);
      expect(stats.total, 8);
      expect(stats.verified, 2);
      expect(stats.unverified, 4);
      expect(stats.pending, 1);
      expect(stats.rejected, 1);
      expect(stats.suspended, 1);
      expect(stats.incomplete, 1);
      expect(stats.recent, 3);
    });

    test('search covers name, email, phone and id; filters combine', () {
      final users = sampleUsers();
      List<String> ids(UserQuery q) => q.apply(users).map((u) => u.id).toList();
      expect(ids(const UserQuery(search: 'kamran')), ['w_ok']);
      expect(ids(const UserQuery(search: 'FARAZ@TEST')), ['w_rejected']);
      expect(ids(const UserQuery(search: '0300 333')), ['w_pending']);
      expect(ids(const UserQuery(search: 'c_banned')), ['c_banned']);
      expect(
        ids(
          const UserQuery(
            filter: UserListFilter.unverified,
            type: UserTypeFilter.workers,
          ),
        ),
        ['w_legacy'],
      );
      expect(ids(const UserQuery(filter: UserListFilter.incomplete)), [
        'c_new',
      ]);
      final oldest = ids(const UserQuery(sort: UserSort.oldest));
      expect(oldest.first, 'w_legacy');
      expect(ids(const UserQuery()).first, 'c_new');
    });

    test('phones are masked for confirmation dialogs', () {
      expect(maskPhone('+923001234567'), '+92•••••••567');
      expect(maskPhone(''), '');
      expect(maskPhone('123'), '•••');
    });
  });

  group('User Management screen', () {
    testWidgets('admin sees stats, users and verification columns', (
      tester,
    ) async {
      await pumpScreen(tester, FakeGateway(sampleUsers()));
      expect(find.text('User Management'), findsOneWidget);
      expect(find.bySemanticsLabel('Total users: 8'), findsOneWidget);
      expect(find.bySemanticsLabel('Pending verification: 1'), findsOneWidget);
      expect(find.bySemanticsLabel('New this week: 3'), findsOneWidget);
      expect(find.text('Kamran Approved'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(resultCount(tester), '8 users');
      expect(tester.takeException(), isNull);
    });

    testWidgets('search and filters narrow the list', (tester) async {
      await pumpScreen(tester, FakeGateway(sampleUsers()));
      await tester.enterText(find.byKey(const Key('user-search')), 'test.pk');
      await tester.pumpAndSettle();
      expect(resultCount(tester), '6 users');
      await tester.enterText(find.byKey(const Key('user-search')), '');
      await tester.tap(find.byKey(const Key('filter-pending')));
      await tester.pumpAndSettle();
      expect(resultCount(tester), '1 user');
      expect(find.text('Danish Pending'), findsOneWidget);
      await tester.tap(find.byKey(const Key('filter-suspended')));
      await tester.pumpAndSettle();
      expect(find.text('Spam Account'), findsOneWidget);
      expect(find.text('Kamran Approved'), findsNothing);
      await tester.tap(find.byKey(const Key('stat-Rejected')));
      await tester.pumpAndSettle();
      expect(find.text('Faraz Rejected'), findsOneWidget);
    });

    testWidgets('paginates 20 users per page', (tester) async {
      final many = [
        for (var i = 0; i < 45; i++)
          user('u$i', name: 'User $i', email: 'u$i@test.pk', daysAgo: i),
      ];
      await pumpScreen(tester, FakeGateway(many));
      expect(find.text('1–20 of 45'), findsOneWidget);
      expect(find.text('User 0'), findsOneWidget);
      await tester.tap(find.byKey(const Key('page-next')));
      await tester.pumpAndSettle();
      expect(find.text('21–40 of 45'), findsOneWidget);
      expect(find.text('User 20'), findsOneWidget);
      expect(find.text('User 0'), findsNothing);
    });

    testWidgets('delete needs a reason and explicit confirmation', (
      tester,
    ) async {
      final gateway = FakeGateway(sampleUsers());
      await pumpScreen(tester, gateway);
      await tester.tap(find.byKey(const Key('delete-w_rejected')));
      await tester.pumpAndSettle();
      expect(find.text('Permanently delete this account?'), findsOneWidget);
      expect(find.text('faraz@test.pk'), findsWidgets);
      expect(find.textContaining('permanent and cannot be undone'), findsOne);
      ButtonStyleButton submit() => tester.widget<ButtonStyleButton>(
        find.byKey(const Key('deletion-submit')),
      );
      expect(submit().onPressed, isNull, reason: 'no reason yet');

      await tester.tap(find.byKey(const Key('deletion-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deletion-confirm')));
      await tester.pump();
      expect(submit().onPressed, isNull, reason: 'Other needs a description');
      await tester.enterText(
        find.byKey(const Key('deletion-reason-detail')),
        'Uses a stolen CNIC',
      );
      await tester.pump();
      expect(submit().onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('deletion-submit')));
      await tester.pumpAndSettle();

      expect(gateway.deleted, [
        ('w_rejected', DeletionReason.other, 'Uses a stolen CNIC'),
      ]);
      expect(find.text('Faraz Rejected'), findsNothing);
      expect(find.textContaining('deleted permanently'), findsOneWidget);
    });

    testWidgets('cancelling the dialog deletes nothing', (tester) async {
      final gateway = FakeGateway(sampleUsers());
      await pumpScreen(tester, gateway);
      await tester.tap(find.byKey(const Key('delete-c_new')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(gateway.deleted, isEmpty);
      expect(find.text('Bilal Unverified'), findsOneWidget);
    });

    testWidgets('a server refusal is shown and the user stays', (tester) async {
      final gateway = FakeGateway(sampleUsers())..failing = {'w_ok'};
      await pumpScreen(tester, gateway);
      await tester.tap(find.byKey(const Key('delete-w_ok')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deletion-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Policy Violation').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deletion-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deletion-submit')));
      await tester.pumpAndSettle();
      expect(find.text('This account has 1 active job.'), findsOneWidget);
      expect(find.text('Kamran Approved'), findsOneWidget);
    });

    testWidgets('the signed-in admin cannot delete or select themselves', (
      tester,
    ) async {
      await pumpScreen(tester, FakeGateway(sampleUsers()));
      final button = tester.widget<IconButton>(
        find.byKey(const Key('delete-admin_me')),
      );
      expect(button.onPressed, isNull);
      final box = tester.widget<Checkbox>(
        find.byKey(const Key('select-admin_me')),
      );
      expect(box.onChanged, isNull);
      expect(find.text('Select all filtered (7)'), findsOneWidget);
    });

    testWidgets('bulk delete: select all, confirm count, progress, report', (
      tester,
    ) async {
      final gateway = FakeGateway(sampleUsers())..failing = {'w_ok'};
      await pumpScreen(tester, gateway);
      await tester.tap(find.byKey(const Key('filter-unverified')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      // Unverified = c_new, w_legacy, c_banned, admin_me (not selectable).
      expect(find.text('Delete selected (3)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bulk-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Permanently delete 3 accounts?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('deletion-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam or Abuse').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deletion-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deletion-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Bulk deletion finished'), findsOneWidget);
      expect(find.text('3 deleted · 0 failed'), findsOneWidget);
      expect(gateway.bulkCalls.single.toSet(), {
        'c_new',
        'w_legacy',
        'c_banned',
      });
      expect(
        gateway.deleted.every((d) => d.$2 == DeletionReason.spamAbuse),
        isTrue,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy Flag'), findsNothing);
    });

    testWidgets('bulk delete reports failures and splits large batches', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 14; i++)
          user('u$i', name: 'User $i', email: 'u$i@test.pk', daysAgo: i),
      ];
      final gateway = FakeGateway(many)..failing = {'u3'};
      await pumpScreen(tester, gateway);
      await tester.tap(find.byKey(const Key('select-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bulk-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deletion-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate Account').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deletion-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deletion-submit')));
      await tester.pumpAndSettle();
      expect(gateway.bulkCalls.map((c) => c.length), [10, 4]);
      expect(find.text('13 deleted · 1 failed'), findsOneWidget);
      expect(find.text('User 3'), findsWidgets);
      expect(find.text('This account has 1 active job.'), findsOneWidget);
    });

    testWidgets('suspension goes through the backend with a reason', (
      tester,
    ) async {
      final gateway = FakeGateway(sampleUsers());
      await pumpScreen(tester, gateway);
      await tester.tap(find.byTooltip('Suspend').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('suspend-confirm')));
      await tester.pump();
      expect(gateway.statusCalls, isEmpty, reason: 'reason required');
      await tester.enterText(find.byKey(const Key('suspend-reason')), 'Spam');
      await tester.tap(find.byKey(const Key('suspend-confirm')));
      await tester.pumpAndSettle();
      expect(gateway.statusCalls.single.$2, isTrue);
      expect(gateway.statusCalls.single.$3, 'Spam');
    });

    testWidgets('phone-width layout shows cards without overflow', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeGateway(sampleUsers()),
        size: const Size(390, 844),
      );
      expect(find.byType(DataTable), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('card-c_ok')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('card-c_ok')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('details show verification and allow approval of pending', (
      tester,
    ) async {
      final gateway = FakeGateway(sampleUsers())
        ..verification = VerificationDetails(
          request: VerificationRequestModel.fromMap('w_pending', const {
            'workerId': 'w_pending',
            'identityStatus': 'pending',
            'cnicFrontPath': 'private_verifications/workers/w_pending/f.jpg',
          }),
        );
      final pending = sampleUsers().firstWhere((u) => u.id == 'w_pending');
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: AdminUserDetailScreen(user: pending, gateway: gateway),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Identity verification'), findsOneWidget);
      expect(find.text('Not uploaded'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('detail-approve')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();
      expect(gateway.approved, isTrue);
    });
  });
}
