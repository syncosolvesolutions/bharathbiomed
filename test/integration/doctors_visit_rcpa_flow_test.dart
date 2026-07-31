import 'package:bharathbiomedpharma/domain/models/pharmacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Doctor proposals + approval, weekly visit plans, today's-visit logging,
/// and RCPA entries. See docs/BUSINESS_OVERVIEW.md §3.
void main() {
  const adminEmail = 'bharathbiomedpharma@gmail.com';

  Future<void> proposeDoctor(WidgetTester tester, {required String name, required String hospital}) async {
    await tester.tap(find.byTooltip('My Doctors'));
    await settle(tester);
    await tester.tap(find.text('Add Doctor'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Doctor Name'), name);
    await tester.enterText(find.widgetWithText(TextFormField, 'Hospital / Clinic Name'), hospital);
    await tester.enterText(find.widgetWithText(TextFormField, 'Address (optional)'), '123 Main Street');

    await tester.tap(find.text('Submit for Approval'));
    await settle(tester);
  }

  testWidgets('positive: a proposed doctor appears in the MR directory once the admin approves it', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await proposeDoctor(tester, name: 'Dr. Anjali Verma', hospital: 'City Care Hospital');
    expect(backend.doctorChangeRequests.requests, hasLength(1));
    expect(backend.doctors.doctors, isEmpty);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    routerOf(tester).push('/admin/doctors/requests');
    await settle(tester);
    expect(find.text('New doctor: Dr. Anjali Verma'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await settle(tester);
    expect(backend.doctors.doctors, hasLength(1));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('My Doctors'));
    await settle(tester);
    expect(find.text('Dr. Anjali Verma'), findsOneWidget);
  });

  testWidgets('negative: a rejected doctor proposal never appears in the directory', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await proposeDoctor(tester, name: 'Dr. Bad Fit', hospital: 'Rejected Hospital');

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    routerOf(tester).push('/admin/doctors/requests');
    await settle(tester);
    await tester.tap(find.text('Reject'));
    await settle(tester);
    // The background card's own "Reject" button is still in the tree behind
    // the modal barrier, so scope this tap to the confirmation dialog.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Reject')));
    await settle(tester);

    expect(backend.doctors.doctors, isEmpty);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('My Doctors'));
    await settle(tester);
    expect(find.text('Dr. Bad Fit'), findsNothing);
    expect(find.text('No doctors assigned yet.\nAsk your admin to assign some, or add one you\'re visiting for the first time.'),
        findsOneWidget);
  });

  testWidgets('positive: MR submits a weekly visit plan and logs today\'s visit', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.doctors.doctors.add(buildDoctor(id: 'doc1', name: 'Dr. Anjali Verma', assignedMrUid: 'mr1'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));

    await tester.tap(find.byTooltip('Weekly Visit Plan'));
    await settle(tester);
    expect(find.text('Not submitted'), findsOneWidget);

    // The controller's initial tab is already today's weekday.
    await tester.tap(find.byType(CheckboxListTile));
    await settle(tester);
    await tester.tap(find.text('Submit for Approval'));
    await settle(tester);
    expect(find.text('Pending approval'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byTooltip("Today's Visits"));
    await settle(tester);

    expect(find.text('Dr. Anjali Verma'), findsOneWidget);
    expect(find.text('Log Visit'), findsOneWidget);

    await tester.tap(find.text('Log Visit'));
    await settle(tester);
    expect(find.text('Log visit — Dr. Anjali Verma'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(backend.doctorVisitLogs.logs, hasLength(1));
    expect(backend.doctorVisitLogs.logs.single.visited, isTrue);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('edge: a visit plan submitted with no doctors selected still submits successfully', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.doctors.doctors.add(buildDoctor(id: 'doc1', name: 'Dr. Anjali Verma', assignedMrUid: 'mr1'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Weekly Visit Plan'));
    await settle(tester);

    // No checkbox toggled — submit an empty plan as-is.
    await tester.tap(find.text('Submit for Approval'));
    await settle(tester);

    expect(find.text('Pending approval'), findsOneWidget);
    expect(find.text('Submitted for approval.'), findsOneWidget);
  });

  testWidgets('positive: MR logs an RCPA entry with an own-brand script count', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.pharmacies.pharmacies.add(buildPharmacy(id: 'ph1', name: 'City Pharmacy'));
    backend.products.departments = ['General'];
    backend.products.products = [buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'General': 0})];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('RCPA Entries'));
    await settle(tester);
    await tester.tap(find.text('New Entry'));
    await settle(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Pharmacy>));
    await settle(tester);
    await tester.tap(find.text('City Pharmacy').last);
    await settle(tester);

    await tester.tap(find.text('Add').first);
    await settle(tester);
    await tester.tap(find.text('Paracetamol'));
    await settle(tester);

    await tester.tap(find.text('Save Entry'));
    await settle(tester);

    expect(backend.rcpa.entries, hasLength(1));
    expect(backend.rcpa.entries.single.ownBrandCounts.single.productName, 'Paracetamol');
  });

  testWidgets('negative: an RCPA entry with no counts at all is blocked', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.pharmacies.pharmacies.add(buildPharmacy(id: 'ph1', name: 'City Pharmacy'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('RCPA Entries'));
    await settle(tester);
    await tester.tap(find.text('New Entry'));
    await settle(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Pharmacy>));
    await settle(tester);
    await tester.tap(find.text('City Pharmacy').last);
    await settle(tester);

    await tester.tap(find.text('Save Entry'));
    await settle(tester);

    expect(find.text('Nothing to log'), findsOneWidget);
    expect(backend.rcpa.entries, isEmpty);
  });
}
