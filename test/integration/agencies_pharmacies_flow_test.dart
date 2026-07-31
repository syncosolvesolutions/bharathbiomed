import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Agencies/pharmacies: any signed-in user can see the full lists; only an
/// Office Admin creates/deactivates directly, anyone else proposes one via
/// an [EntityChangeRequest] the Office Admin must approve. See
/// docs/BUSINESS_OVERVIEW.md §4.
void main() {
  testWidgets('positive: an MR-proposed agency goes live once the Office Admin approves it', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar'),
      buildEmployee(uid: 'oa1', username: 'office_admin', category: 'office_administration'),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Agencies'));
    await settle(tester);
    expect(find.text('Propose Agency'), findsOneWidget);

    await tester.tap(find.text('Propose Agency'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Agency Name'), 'MedSupply Co');
    await tester.tap(find.text('Submit for Approval'));
    await settle(tester);

    expect(backend.entityChangeRequests.requests, hasLength(1));
    expect(backend.agencies.agencies, isEmpty);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'oa1', email: null));
    await tester.tap(find.byTooltip('Agency / Pharmacy Requests'));
    await settle(tester);
    expect(find.text('New Agency: MedSupply Co'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await settle(tester);
    expect(backend.agencies.agencies, hasLength(1));
    expect(backend.agencies.agencies.single.active, isTrue);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Agencies'));
    await settle(tester);
    expect(find.text('MedSupply Co'), findsOneWidget);
  });

  testWidgets('negative: a rejected agency proposal never appears in the directory', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar'),
      buildEmployee(uid: 'oa1', username: 'office_admin', category: 'office_administration'),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Agencies'));
    await settle(tester);
    await tester.tap(find.text('Propose Agency'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Agency Name'), 'Sketchy Supplies');
    await tester.tap(find.text('Submit for Approval'));
    await settle(tester);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'oa1', email: null));
    await tester.tap(find.byTooltip('Agency / Pharmacy Requests'));
    await settle(tester);
    await tester.tap(find.text('Reject'));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Reject')));
    await settle(tester);

    expect(backend.agencies.agencies, isEmpty);
  });

  testWidgets('positive: an Office Admin creates an agency directly, no approval needed', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'oa1', username: 'office_admin', category: 'office_administration'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'oa1', email: null));
    await tester.tap(find.byTooltip('Agencies'));
    await settle(tester);
    expect(find.text('Add Agency'), findsOneWidget);

    await tester.tap(find.text('Add Agency'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Agency Name'), 'Direct Supply Co');
    // "Add Agency" also matches the previous screen's still-mounted FAB and
    // this screen's own AppBar title — scope the tap to the submit button.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Agency'));
    await settle(tester);

    expect(backend.entityChangeRequests.requests, isEmpty);
    expect(backend.agencies.agencies, hasLength(1));
    expect(backend.agencies.agencies.single.name, 'Direct Supply Co');
  });

  testWidgets('edge: an Office Admin can deactivate then reactivate an agency', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'oa1', username: 'office_admin', category: 'office_administration'));
    backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'oa1', email: null));
    await tester.tap(find.byTooltip('Agencies'));
    await settle(tester);

    await tester.tap(find.byTooltip('Deactivate'));
    await settle(tester);
    expect(backend.agencies.agencies.single.active, isFalse);
    expect(find.textContaining('Inactive'), findsOneWidget);

    await tester.tap(find.byTooltip('Reactivate'));
    await settle(tester);
    expect(backend.agencies.agencies.single.active, isTrue);
  });

  testWidgets('positive: pharmacy proposal + approval mirrors the agency flow', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar'),
      buildEmployee(uid: 'oa1', username: 'office_admin', category: 'office_administration'),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Pharmacies'));
    await settle(tester);
    await tester.tap(find.text('Propose Pharmacy'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Pharmacy / Chemist Name'), 'City Pharmacy');
    await tester.tap(find.text('Submit for Approval'));
    await settle(tester);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'oa1', email: null));
    await tester.tap(find.byTooltip('Agency / Pharmacy Requests'));
    await settle(tester);
    expect(find.text('New Pharmacy: City Pharmacy'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await settle(tester);

    expect(backend.pharmacies.pharmacies, hasLength(1));
    expect(backend.pharmacies.pharmacies.single.name, 'City Pharmacy');
  });
}
