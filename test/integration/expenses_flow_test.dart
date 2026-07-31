import 'package:bharathbiomedpharma/domain/models/expense_claim.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Expense claims: an MR files a TA/DA claim, a manager holding
/// `approve_expenses` approves/rejects it — no dispatch-equivalent step.
/// See docs/BUSINESS_OVERVIEW.md §6.
void main() {
  Future<void> fileClaim(WidgetTester tester, {required String amount}) async {
    await tester.tap(find.byTooltip('My Expense Claims'));
    await settle(tester);
    await tester.tap(find.text('File Claim'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), amount);
    await tester.tap(find.text('Submit Claim'));
    await settle(tester);
  }

  testWidgets('positive: file -> approve -> MR sees it approved', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mgr1', username: 'priya_manager', permissions: [Permission.approveExpenses.value]),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await fileClaim(tester, amount: '450');
    expect(backend.expenseClaims.claims, hasLength(1));
    expect(backend.expenseClaims.claims.single.status, ExpenseClaimStatus.pending);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Expense Claims'));
    await settle(tester);
    expect(find.text('Test User — Travel'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await settle(tester);
    expect(backend.expenseClaims.claims.single.status, ExpenseClaimStatus.approved);
    expect(find.text('Nothing needs attention right now.'), findsOneWidget);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('My Expense Claims'));
    await settle(tester);
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('negative: an amount of 0 is rejected', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await fileClaim(tester, amount: '0');

    expect(find.text('Invalid amount'), findsOneWidget);
    expect(backend.expenseClaims.claims, isEmpty);
  });

  testWidgets('negative: a manager without approve_expenses sees a read-only queue', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mgr1', username: 'priya_manager'), // no permissions
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await fileClaim(tester, amount: '450');

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Expense Claims'));
    await settle(tester);

    expect(find.text('Test User — Travel'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('edge: a rejected claim is terminal and shows the reason to the MR', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mgr1', username: 'priya_manager', permissions: [Permission.approveExpenses.value]),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await fileClaim(tester, amount: '450');

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Expense Claims'));
    await settle(tester);
    await tester.tap(find.text('Reject'));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Reject')));
    await settle(tester);

    expect(backend.expenseClaims.claims.single.status, ExpenseClaimStatus.rejected);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('My Expense Claims'));
    await settle(tester);
    expect(find.text('Rejected'), findsOneWidget);
  });
}
