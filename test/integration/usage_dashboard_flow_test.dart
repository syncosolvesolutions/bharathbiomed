import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Usage dashboard: per-MR app-open count, total time, last location —
/// reachable by the admin (everyone) or a manager (their own downline
/// only). See docs/BUSINESS_OVERVIEW.md §9.3/§10.
void main() {
  const adminEmail = 'bharathbiomedpharma@gmail.com';

  // The dashboard card's session-count/duration line is a bare `RichText`
  // (not wrapped in a `Text`/`Text.rich`), which `find.text`/
  // `find.textContaining` don't match at all — they only look at `Text`
  // widgets.
  Finder richTextContaining(String substring) =>
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains(substring));

  testWidgets('positive: admin sees session count/duration and can drill into one employee', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    final now = DateTime.now();
    backend.usageSessions.sessions.addAll([
      buildUsageSession(
        id: 's1',
        employeeUid: 'mr1',
        openedAt: now.subtract(const Duration(days: 1, hours: 1)),
        closedAt: now.subtract(const Duration(days: 1)),
      ),
      buildUsageSession(
        id: 's2',
        employeeUid: 'mr1',
        openedAt: now.subtract(const Duration(minutes: 30)),
        closedAt: now.subtract(const Duration(minutes: 10)),
        latitude: 12.9,
        longitude: 77.6,
      ),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Usage Dashboard'));
    await settle(tester);

    expect(richTextContaining('2 sessions'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);

    await tester.tap(find.text('Test User'));
    await settle(tester);
    expect(find.text('No recorded sessions yet.'), findsNothing);
    expect(find.textContaining('12.90000, 77.60000'), findsOneWidget);
  });

  testWidgets('positive: a manager sees only their own downline, not the whole company', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', firstName: 'Rajesh', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mr2', username: 'other_mr', firstName: 'Other'), // not in mgr1's downline
      buildEmployee(uid: 'mgr1', username: 'priya_manager', firstName: 'Priya'),
    ]);
    backend.usageSessions.sessions.addAll([
      buildUsageSession(id: 's1', employeeUid: 'mr1', openedAt: DateTime.now()),
      buildUsageSession(id: 's2', employeeUid: 'mr2', openedAt: DateTime.now()),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Usage & Location'));
    await settle(tester);

    expect(find.text('Rajesh User'), findsOneWidget);
    expect(find.text('Other User'), findsNothing);
  });

  testWidgets('edge: an employee with zero sessions shows "Never opened" instead of erroring', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Usage Dashboard'));
    await settle(tester);

    expect(richTextContaining('0 sessions'), findsOneWidget);
    expect(richTextContaining('Never opened'), findsOneWidget);
  });
}
