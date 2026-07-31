import 'package:bharathbiomedpharma/domain/models/agency.dart';
import 'package:bharathbiomedpharma/domain/models/order.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Orders: submit -> approve/reject -> dispatch -> mark delivered. See
/// docs/BUSINESS_OVERVIEW.md §4 for the lifecycle and §8 for how
/// `approve_orders`/`dispatch_orders` gate the team workflow screen.
void main() {
  Future<void> goToMyOrders(WidgetTester tester) async {
    await tester.tap(find.byTooltip('My Orders'));
    await settle(tester);
  }

  Future<void> goToOrderWorkflow(WidgetTester tester) async {
    await tester.tap(find.byTooltip('My Team'));
    await settle(tester);
    await tester.tap(find.text('Order Workflow'));
    await settle(tester);
  }

  /// Fills in the order form (agency + one line for [productName]) and taps
  /// Submit — shared by every test that needs a starting order.
  Future<void> placeOrder(WidgetTester tester, {required String agencyName, required String productName}) async {
    await goToMyOrders(tester);
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

  testWidgets('positive: submit -> approve -> dispatch decrements stock -> MR marks delivered', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(
        uid: 'mgr1',
        username: 'priya_manager',
        permissions: [Permission.approveOrders.value, Permission.dispatchOrders.value],
      ),
    ]);
    backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));
    backend.products.departments = ['General'];
    backend.products.products = [
      buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'General': 0}, stockQuantity: 20, unitPrice: 5),
    ];

    // --- MR places the order ---
    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await placeOrder(tester, agencyName: 'MedSupply Co', productName: 'Paracetamol');
    expect(backend.orders.orders, hasLength(1));
    expect(backend.orders.orders.single.status, OrderStatus.pending);

    // Re-launch as the MR to see the freshly-placed order (My Orders'
    // provider isn't invalidated by the form popping — a fresh app launch
    // reads it straight from the shared fake backend either way).
    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await goToMyOrders(tester);
    expect(find.text('Pending approval'), findsOneWidget);

    // --- Manager approves, then dispatches ---
    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await goToOrderWorkflow(tester);
    expect(find.text('MedSupply Co — Test User'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await settle(tester);
    expect(backend.orders.orders.single.status, OrderStatus.approved);

    await tester.tap(find.text('Dispatch'));
    await settle(tester);
    expect(backend.orders.orders.single.status, OrderStatus.dispatched);
    expect(backend.products.stockFor('p1'), 19);
    expect(find.text('Nothing needs attention right now.'), findsOneWidget);

    // --- MR marks it delivered ---
    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await goToMyOrders(tester);
    expect(find.text('Mark Delivered'), findsOneWidget);
    await tester.tap(find.text('Mark Delivered'));
    await settle(tester);

    expect(backend.orders.orders.single.status, OrderStatus.delivered);
    expect(find.text('Delivered'), findsOneWidget);
  });

  testWidgets('negative: submitting with no products added is blocked', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await goToMyOrders(tester);
    await tester.tap(find.text('Place Order'));
    await settle(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Agency>));
    await settle(tester);
    await tester.tap(find.text('MedSupply Co').last);
    await settle(tester);

    await tester.tap(find.text('Submit Order'));
    await settle(tester);

    expect(find.text('No products added'), findsOneWidget);
    expect(backend.orders.orders, isEmpty);
  });

  testWidgets('negative: a quantity of 0 is rejected', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));
    backend.products.departments = ['General'];
    backend.products.products = [buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'General': 0})];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await goToMyOrders(tester);
    await tester.tap(find.text('Place Order'));
    await settle(tester);

    await tester.tap(find.byType(DropdownButtonFormField<Agency>));
    await settle(tester);
    await tester.tap(find.text('MedSupply Co').last);
    await settle(tester);
    await tester.tap(find.text('Add'));
    await settle(tester);
    await tester.tap(find.text('Paracetamol'));
    await settle(tester);

    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Qty'), '0');
    await tester.tap(find.text('Submit Order'));
    await settle(tester);

    expect(find.text('Invalid quantity'), findsOneWidget);
    expect(backend.orders.orders, isEmpty);
  });

  testWidgets('negative: a manager without approve_orders sees a read-only queue', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mgr1', username: 'priya_manager'), // no permissions at all
    ]);
    backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));
    backend.products.departments = ['General'];
    backend.products.products = [buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'General': 0})];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await placeOrder(tester, agencyName: 'MedSupply Co', productName: 'Paracetamol');

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await goToOrderWorkflow(tester);

    expect(find.text('MedSupply Co — Test User'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('negative: dispatch is blocked when stock is insufficient', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(
        uid: 'mgr1',
        username: 'priya_manager',
        permissions: [Permission.approveOrders.value, Permission.dispatchOrders.value],
      ),
    ]);
    backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));
    backend.products.departments = ['General'];
    backend.products.products = [
      buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'General': 0}, stockQuantity: 0),
    ];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await placeOrder(tester, agencyName: 'MedSupply Co', productName: 'Paracetamol');

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await goToOrderWorkflow(tester);
    await tester.tap(find.text('Approve'));
    await settle(tester);
    // The "Order approved." snackbar is still showing (its default 4s
    // duration hasn't elapsed) — clear it so the "Failed:" one below shows
    // immediately instead of queuing behind it.
    clearSnackBars(tester);
    await tester.tap(find.text('Dispatch'));
    await settle(tester);

    expect(find.textContaining('Failed:'), findsOneWidget);
    expect(backend.orders.orders.single.status, OrderStatus.approved);
    expect(backend.products.stockFor('p1'), 0);
  });

  testWidgets('edge: stock exactly equal to the ordered quantity still dispatches', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(
        uid: 'mgr1',
        username: 'priya_manager',
        permissions: [Permission.approveOrders.value, Permission.dispatchOrders.value],
      ),
    ]);
    backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));
    backend.products.departments = ['General'];
    backend.products.products = [
      buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'General': 0}, stockQuantity: 1),
    ];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await placeOrder(tester, agencyName: 'MedSupply Co', productName: 'Paracetamol');

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await goToOrderWorkflow(tester);
    await tester.tap(find.text('Approve'));
    await settle(tester);
    await tester.tap(find.text('Dispatch'));
    await settle(tester);

    expect(backend.orders.orders.single.status, OrderStatus.dispatched);
    expect(backend.products.stockFor('p1'), 0);
  });

  testWidgets('edge: a rejected order is terminal and never re-offered for action', (tester) async {
    final backend = TestBackend();
    backend.employees.employees.addAll([
      buildEmployee(uid: 'mr1', username: 'rajesh_kumar', reportingChainUids: const ['mgr1']),
      buildEmployee(uid: 'mgr1', username: 'priya_manager', permissions: [Permission.approveOrders.value]),
    ]);
    backend.agencies.agencies.add(buildAgency(id: 'a1', name: 'MedSupply Co'));
    backend.products.departments = ['General'];
    backend.products.products = [buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'General': 0})];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await placeOrder(tester, agencyName: 'MedSupply Co', productName: 'Paracetamol');

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mgr1', email: null));
    await goToOrderWorkflow(tester);
    await tester.tap(find.text('Reject'));
    await settle(tester);
    // The background card's own "Reject" button is still in the tree behind
    // the modal barrier, so scope this tap to the confirmation dialog.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Reject')));
    await settle(tester);

    expect(backend.orders.orders.single.status, OrderStatus.rejected);
    expect(find.text('Nothing needs attention right now.'), findsOneWidget);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    await goToMyOrders(tester);
    expect(find.text('Rejected'), findsOneWidget);
  });
}
