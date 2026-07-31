import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Profile editing, the mandatory first-login completion gate, and the
/// once-a-year birthday celebration. See docs/BUSINESS_OVERVIEW.md §11.
/// Profile *photo* changes can't be driven through this suite (no real
/// image picker available) — both forms make that clear where it matters.
void main() {
  String isoDate(DateTime date) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${pad2(date.month)}-${pad2(date.day)}';
  }

  testWidgets('positive: MR edits their name and mobile number', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar', firstName: 'Rajesh', lastName: 'Kumar'));
    backend.employees.currentUid = 'mr1';

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Profile'));
    await settle(tester);

    expect(find.text('Username'), findsOneWidget); // read-only field label present

    await tester.enterText(find.widgetWithText(TextFormField, 'First Name'), 'Rajesh Updated');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mobile Number'), '9876543210');
    await tester.tap(find.text('Save Changes'));
    await settle(tester);

    expect(find.text('Profile updated.'), findsOneWidget);
    final updated = backend.employees.employees.single;
    expect(updated.firstName, 'Rajesh Updated');
    expect(updated.mobileNumber, '9876543210');
  });

  testWidgets('positive: a birthday celebration shows for an MR on their birthday, dismissible', (tester) async {
    final backend = TestBackend();
    final today = DateTime.now();
    backend.employees.employees.add(buildEmployee(
      uid: 'mr1',
      username: 'rajesh_kumar',
      firstName: 'Rajesh',
      dateOfBirth: isoDate(DateTime(today.year - 30, today.month, today.day)),
    ));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));

    expect(find.textContaining('Happy Birthday'), findsOneWidget);
    await tester.tap(find.text('Thank You!'));
    await settle(tester);
    expect(find.textContaining('Happy Birthday'), findsNothing);
  });

  testWidgets('negative: completing the first-login profile without a photo is blocked', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr4', username: 'new_mr', profileCompleted: false));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr4', email: null));
    expect(find.text('Complete Your Profile'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'First Name'), 'New');
    await tester.enterText(find.widgetWithText(TextFormField, 'Last Name'), 'Hire');
    await tester.tap(find.text('Save & Continue'));
    await settle(tester);

    expect(find.text('Photo required'), findsOneWidget);
    expect(backend.employees.employees.single.profileCompleted, isFalse);
  });
}
