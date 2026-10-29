// TEMPORARY diagnostic (not part of the test suite). Run:
//   flutter test tool/diag/worker_home_diag_test.dart > _claude_tmp/diag.log 2>&1
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_link/design_system/skillnova_theme.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_models.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_repository.dart';
import 'package:skill_link/screens/worker_screens/home/worker_home_screen.dart';

class _Repo implements WorkerHomeRepository {
  _Repo(this.profile);
  final WorkerHomeProfile profile;
  @override
  String? get currentWorkerId => profile.uid;
  @override
  Stream<WorkerHomeProfile> watchProfile() => Stream.value(profile);
  @override
  Stream<WorkerActiveJobsSnapshot> watchActiveJobs() =>
      Stream.value(const WorkerActiveJobsSnapshot());
  @override
  Stream<List<WorkerLeadPreview>> watchLeads(WorkerHomeProfile worker) =>
      Stream.value(const []);
}

void dump(WidgetTester tester, String label) {
  final texts = find
      .byType(Text, skipOffstage: false)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '<rich>')
      .toList();
  final onstage = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '<rich>')
      .toList();
  debugPrint('[$label] ALL TEXT: $texts');
  debugPrint('[$label] ONSTAGE TEXT: $onstage');
  for (final e in find.byType(Scrollable, skipOffstage: false).evaluate()) {
    final s = e.widget as Scrollable;
    final state = (e as StatefulElement).state as ScrollableState;
    debugPrint('[$label] Scrollable axis=${s.axisDirection} '
        'pixels=${state.position.pixels} max=${state.position.maxScrollExtent} '
        'size=${e.size}');
  }
  final exception = tester.takeException();
  debugPrint('[$label] pending exception: $exception');
}

void main() {
  testWidgets('diag zero-credit home', (tester) async {
    final data = <String, dynamic>{
      'role': 'worker',
      'name': 'Muhammad Ahmed Professional With A Long Display Name',
      'skill': 'AC Technician',
      'profileCompleted': true,
      'identityVerificationStatus': 'approved',
      'canAcceptJobs': true,
      'isBlocked': false,
      'accountStatus': 'active',
      'credits': 0,
      'rating': 4.9,
      'totalReviews': 28,
      'lat': 31.5204,
      'lng': 74.3587,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: SkillNovaTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.15)),
          child: WorkerHomeScreen(
            repository: _Repo(WorkerHomeProfile(uid: 'w', data: data)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    dump(tester, 'initial');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    dump(tester, 'after-drag');
  });
}
