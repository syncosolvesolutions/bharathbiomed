import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// UCPMP compliance dashboard: aggregated per-doctor (not per-MR — the real
/// compliance question is "has this doctor received too much", regardless
/// of who gave it). This tenant's configured annual limit is 0, so any
/// logged value at all flags a doctor. See docs/BUSINESS_OVERVIEW.md §7.
void main() {
  const adminEmail = 'bharathbiomedpharma@gmail.com';

  testWidgets('positive: entries aggregate per doctor, highest total first, over-limit flagged', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.complianceLogs.logs.addAll([
      buildComplianceLog(id: 'c1', mrUid: 'mr1', doctorId: 'd1', doctorName: 'Dr. Low', value: 100),
      buildComplianceLog(id: 'c2', mrUid: 'mr1', doctorId: 'd2', doctorName: 'Dr. High', value: 300),
      buildComplianceLog(id: 'c3', mrUid: 'mr1', doctorId: 'd2', doctorName: 'Dr. High', value: 250),
      buildComplianceLog(id: 'c4', mrUid: 'mr1', doctorId: 'd3', doctorName: 'Dr. Zero', value: 0),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    routerOf(tester).go('/team/compliance');
    await settle(tester);

    expect(find.text('2 entries • value 550.00 this year — over limit'), findsOneWidget);
    expect(find.text('1 entry • value 100.00 this year — over limit'), findsOneWidget);
    // Dr. Zero's total is exactly 0, which is not > the tenant's limit of 0 — not over limit.
    expect(find.text('1 entry • value 0.00 this year'), findsOneWidget);
  });

  testWidgets('edge: no compliance entries this year shows the empty state, not an error', (tester) async {
    final backend = TestBackend();

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    routerOf(tester).go('/team/compliance');
    await settle(tester);

    expect(find.text('No compliance entries logged this year.'), findsOneWidget);
  });

  testWidgets('positive: a manager sees only their downline\'s entries, not the whole company', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mr2', username: 'other_mr'), // not in mgr1's downline
      buildEmployee(uid: 'mgr1', username: 'priya_manager'),
    ]);
    backend.complianceLogs.logs.addAll([
      buildComplianceLog(id: 'c1', mrUid: 'mr1', doctorId: 'd1', doctorName: 'In Downline', value: 100),
      buildComplianceLog(id: 'c2', mrUid: 'mr2', doctorId: 'd2', doctorName: 'Outside Downline', value: 100),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    routerOf(tester).go('/team/compliance');
    await settle(tester);

    expect(find.text('In Downline'), findsOneWidget);
    expect(find.text('Outside Downline'), findsNothing);
  });
}
