import 'package:bharathbiomedpharma/domain/models/agency.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Sales targets: set by a manager for their downline, achievement always
/// computed live from that employee's own orders. See
/// docs/BUSINESS_OVERVIEW.md §5.
void main() {
  Future<void> placeOrder(WidgetTester tester, {required String agencyName, required String productName}) async {
    await tester.tap(find.byTooltip('My Orders'));
    await settle(tester);
    await tester.tap(find.text('Place Order'));
    await settle(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Agency>));
    await settle(tester);
    await tester.tap(find.text(agencyName).last);
    await settle(tester);
    await tester.tap(find.text('Add'));
    await settle(tester);
    await tester.tap(find.text(productName));
    await settle(tester);

    await tester.tap(find.text('Submit Order'));
    await settle(tester);
  }

  Future<void> approveOrder(WidgetTester tester) async {
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Order Workflow'));
    await settle(tester);
    // Both orders are pending, so both show an "Approve" button — approve
    // only the first, leaving the second one still pending on purpose.
    await tester.tap(find.text('Approve').first);
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
  }

  testWidgets(
    'positive: a manager sets a target and the MR sees achievement from approved orders only',
    (tester) async {
      final backend = TestBackend();
      backend.employees.employees.addAll([
        buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
        buildEmployee(
          uid: 'mgr1',
          username: 'priya_manager',
          permissions: [Permission.approveOrders.value, Permission.manageTargets.value],
        ),
      ]);
      backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));
      backend.products.departments = ['General'];
      backend.products.products = [
        buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'General': 0}, unitPrice: 100),
      ];

      // MR places two orders — only one will be approved. Each `placeOrder`
      // starts from the catalog screen's "My Orders" icon, so re-launch
      // between them rather than reusing the first order's now-MyOrdersScreen
      // session (which has no such icon of its own).
      await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
      await placeOrder(tester, agencyName: 'MedSupply Co', productName: 'Paracetamol');
      await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
      await placeOrder(tester, agencyName: 'MedSupply Co', productName: 'Paracetamol');
      expect(backend.orders.orders, hasLength(2));

      // Manager approves exactly one, then sets a monthly target from Team
      // Targets' per-row "Set Target" action.
      await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
      await approveOrder(tester);

      // approveOrder's pageBack already lands back on My Team.
      await tester.tap(find.text('Team Targets'));
      await settle(tester);
      expect(find.text('Set Target'), findsOneWidget);

      await tester.tap(find.text('Set Target'));
      await settle(tester);
      // The value field is the only TextFormField on this screen (employee
      // is preselected via the row tapped, period defaults to the current
      // month).
      await tester.enterText(find.byType(TextFormField), '1000');
      await tester.tap(find.text('Save Target'));
      await settle(tester);

      expect(backend.salesTargets.fetchForEmployee('mr1', _currentPeriod()), completion(isNotNull));

      // MR sees achievement counting only the approved order (100), not the
      // still-pending one.
      await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
      await tester.tap(find.byTooltip('My Target'));
      await settle(tester);

      expect(find.textContaining('100.00 of 1000.00'), findsOneWidget);
    },
  );

  testWidgets('negative: a manager without manage_targets cannot set a target', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mgr1', username: 'priya_manager'), // no permissions
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Team Targets'));
    await settle(tester);

    expect(find.text('Set Target'), findsNothing);
  });

  testWidgets('edge: no target set this month and zero orders shows 0%, not an error', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await tester.tap(find.byTooltip('My Target'));
    await settle(tester);

    expect(find.text('No target has been set for you this month yet.'), findsOneWidget);
  });
}

String _currentPeriod() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
}
