import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:bharathbiomedpharma/domain/models/reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Reminders: personal to-dos for both admin and MR; the admin can also
/// assign one directly to an MR. See docs/BUSINESS_OVERVIEW.md §9.4.
void main() {
  const adminEmail = 'bharathbiomedpharma@gmail.com';

  testWidgets('positive: MR creates a reminder for themselves, completes it, then deletes it', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Reminders'));
    await settle(tester);
    expect(find.text('No reminders yet.\nTap + to add one.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_alert_outlined));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Call distributor');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(backend.reminders.reminders, hasLength(1));
    expect(backend.reminders.reminders.single.ownerUid, 'mr1');
    expect(find.text('Call distributor'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    expect(backend.reminders.reminders.single.completed, isTrue);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);
    expect(backend.reminders.reminders, isEmpty);
  });

  testWidgets('positive: an admin can assign a reminder directly to an MR', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Reminders'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add_alert_outlined));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Visit North Zone');
    await tester.tap(find.byType(DropdownButtonFormField<Employee?>));
    await settle(tester);
    await tester.tap(find.text('Test User').last);
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(backend.reminders.reminders.single.ownerUid, 'mr1');
    expect(backend.reminders.reminders.single.createdByUid, 'admin1');
    // The admin's own reminder list doesn't show it — it belongs to the MR.
    expect(find.text('Visit North Zone'), findsNothing);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Reminders'));
    await settle(tester);
    expect(find.text('Visit North Zone'), findsOneWidget);
  });

  testWidgets('edge: an overdue, incomplete reminder is flagged', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.reminders.reminders.add(Reminder(
      id: 'r1',
      ownerUid: 'mr1',
      ownerName: 'Test User',
      createdByUid: 'mr1',
      createdByName: 'Test User',
      title: 'Follow up on stock request',
      dueAt: DateTime.now().subtract(const Duration(days: 1)),
    ));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('Reminders'));
    await settle(tester);

    expect(find.textContaining('Overdue'), findsOneWidget);
  });
}
