import 'package:bharathbiomedpharma/domain/models/doctor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// UCPMP compliance logging: append-only, no approval step — see
/// docs/BUSINESS_OVERVIEW.md §7. The team-side per-doctor dashboard isn't
/// covered by this file (backlog).
void main() {
  testWidgets('positive: MR logs a compliance entry and sees it in their own log', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.doctors.doctors.add(buildDoctor(id: 'doc1', name: 'Dr. Anjali Verma', assignedMrUid: 'mr1'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Compliance Log'));
    await settle(tester);
    expect(find.textContaining('No compliance entries yet'), findsOneWidget);

    await tester.tap(find.text('Log Entry'));
    await settle(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Doctor>));
    await settle(tester);
    await tester.tap(find.text('Dr. Anjali Verma').last);
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Value'), '2500');
    await tester.tap(find.text('Save Entry'));
    await settle(tester);

    expect(backend.complianceLogs.logs, hasLength(1));
    expect(backend.complianceLogs.logs.single.doctorName, 'Dr. Anjali Verma');
    expect(backend.complianceLogs.logs.single.value, 2500);
    expect(find.textContaining('Dr. Anjali Verma — Product Sample'), findsOneWidget);
  });

  testWidgets('negative: saving with no doctor selected is blocked', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.doctors.doctors.add(buildDoctor(id: 'doc1', name: 'Dr. Anjali Verma', assignedMrUid: 'mr1'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Compliance Log'));
    await settle(tester);
    await tester.tap(find.text('Log Entry'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Value'), '2500');
    await tester.tap(find.text('Save Entry'));
    await settle(tester);

    expect(find.text('Doctor required'), findsOneWidget);
    expect(backend.complianceLogs.logs, isEmpty);
  });

  testWidgets('negative: a negative value is blocked', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.doctors.doctors.add(buildDoctor(id: 'doc1', name: 'Dr. Anjali Verma', assignedMrUid: 'mr1'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Compliance Log'));
    await settle(tester);
    await tester.tap(find.text('Log Entry'));
    await settle(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Doctor>));
    await settle(tester);
    await tester.tap(find.text('Dr. Anjali Verma').last);
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Value'), '-5');
    await tester.tap(find.text('Save Entry'));
    await settle(tester);

    expect(find.text('Invalid value'), findsOneWidget);
    expect(backend.complianceLogs.logs, isEmpty);
  });
}
