import 'package:bharathbiomedpharma/domain/models/doctor_change_request.dart';
import 'package:bharathbiomedpharma/domain/models/doctor_visit_log.dart';
import 'package:bharathbiomedpharma/domain/models/doctor_visit_plan.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:bharathbiomedpharma/domain/models/rcpa_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// My Team hub: reachable by any signed-in employee, with empty states for
/// anyone who doesn't actually manage anyone. `approve_requests` is the one
/// permission that changes which *tiles* show (Doctor Requests, Agency /
/// Pharmacy Requests) rather than just gating actions within a screen — see
/// docs/BUSINESS_OVERVIEW.md §8.
void main() {
  testWidgets('positive: a field manager holding approve_requests sees and can use both request-review tiles',
      (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar'),
      buildEmployee(uid: 'abm1', username: 'area_manager', permissions: [Permission.approveRequests.value]),
    ]);
    backend.doctorChangeRequests.requests.add(
      // Mirrors what `submitCreate` would have queued.
      DoctorChangeRequest(
        id: 'req1',
        type: DoctorChangeType.create,
        proposedData: const {'name': 'Dr. Anjali Verma', 'hospitalName': 'City Care Hospital'},
        requestedByUid: 'mr1',
        requestedByName: 'Test User',
      ),
    );

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'abm1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);

    expect(find.text('Doctor Requests'), findsOneWidget);
    expect(find.text('Agency / Pharmacy Requests'), findsOneWidget);

    await tester.tap(find.text('Doctor Requests'));
    await settle(tester);
    expect(find.text('New doctor: Dr. Anjali Verma'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await settle(tester);

    expect(backend.doctorChangeRequests.requests.single.status, DoctorChangeStatus.approved);
    expect(backend.doctors.doctors, hasLength(1));
  });

  testWidgets('negative: a manager without approve_requests sees neither request-review tile', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mgr1', username: 'priya_manager'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);

    expect(find.text('Doctor Requests'), findsNothing);
    expect(find.text('Agency / Pharmacy Requests'), findsNothing);
  });

  testWidgets('positive: a manager holding approve_requests approves a submitted weekly visit plan', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['abm1']),
      buildEmployee(uid: 'abm1', username: 'area_manager', permissions: [Permission.approveRequests.value]),
    ]);
    await backend.doctorVisitPlans.save(DoctorVisitPlan(
      mrUid: 'mr1',
      doctorIdsByWeekday: const {
        'monday': ['doc1']
      },
      status: VisitPlanStatus.pending,
    ));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'abm1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Visit Plan Approvals'));
    await settle(tester);

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('1 planned visit across the week'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await settle(tester);

    final plan = await backend.doctorVisitPlans.loadCached('mr1');
    expect(plan.status, VisitPlanStatus.approved);
  });

  testWidgets('edge: a plain MR with no downline gets an empty state, not an error, on My Team screens',
      (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Visit Logs'));
    await settle(tester);

    expect(find.textContaining('Failed'), findsNothing);
  });

  testWidgets('positive: a manager sees their downline MR\'s logged visits on the Visit Logs dashboard',
      (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(
          uid: 'mr1', username: 'rajesh_kumar', firstName: 'Rajesh', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mgr1', username: 'priya_manager', firstName: 'Priya'),
    ]);
    backend.doctorVisitLogs.logs.add(DoctorVisitLog(
      id: 'log1',
      mrUid: 'mr1',
      doctorId: 'doc1',
      doctorName: 'Dr. Anjali Verma',
      visitDate: '2026-07-01',
      createdAt: DateTime(2026, 7, 1),
    ));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Visit Logs'));
    await settle(tester);

    expect(find.text('Rajesh User'), findsOneWidget);
    // The count/last-visit subtitle is a raw RichText (not Text.rich), so
    // the default text finder — which only inspects Text widgets — needs
    // findRichText:true to look inside it.
    expect(find.textContaining('1 visit logged', findRichText: true), findsOneWidget);
    expect(find.textContaining('Dr. Anjali Verma', findRichText: true), findsOneWidget);
  });

  testWidgets('positive: a manager sees their downline MR\'s logged RCPA entries on the RCPA dashboard',
      (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(
          uid: 'mr1', username: 'rajesh_kumar', firstName: 'Rajesh', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mgr1', username: 'priya_manager', firstName: 'Priya'),
    ]);
    backend.rcpa.entries.add(RcpaEntry(
      id: 'entry1',
      mrUid: 'mr1',
      pharmacyId: 'ph1',
      pharmacyName: 'City Pharmacy',
      auditDate: '2026-07-01',
      createdAt: DateTime(2026, 7, 1),
    ));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('RCPA Entries'));
    await settle(tester);

    expect(find.text('Rajesh User'), findsOneWidget);
    expect(find.textContaining('1 entry logged', findRichText: true), findsOneWidget);
    expect(find.textContaining('City Pharmacy', findRichText: true), findsOneWidget);
  });
}
