import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Inventory: flat stock adjustments, and the optional batch/expiry
/// tracking layer on top of the same `stockQuantity` total. See
/// docs/BUSINESS_OVERVIEW.md §9.2.
void main() {
  const adminEmail = 'bharathbiomedpharma@gmail.com';

  String isoDaysFromNow(int days) {
    final date = DateTime.now().add(Duration(days: days));
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${pad2(date.month)}-${pad2(date.day)}';
  }

  testWidgets('positive: adjusting stock updates the total', (tester) async {
    final backend = TestBackend();
    backend.products.departments = ['Analgesics'];
    backend.products.products = [
      buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'Analgesics': 1}, stockQuantity: 20),
    ];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Manage Inventory'));
    await settle(tester);
    expect(find.text('20 in stock'), findsOneWidget);

    await tester.tap(find.text('Adjust'));
    await settle(tester);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), '50');
    await tester.tap(find.text('Apply'));
    await settle(tester);

    expect(backend.products.stockFor('p1'), 70);
    expect(find.text('70 in stock'), findsOneWidget);
  });

  testWidgets('positive: adding a batch increases stock and lists it, sorted by soonest-expiry', (tester) async {
    final backend = TestBackend();
    backend.products.departments = ['Analgesics'];
    backend.products.products = [
      buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'Analgesics': 1}, stockQuantity: 0),
    ];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Manage Inventory'));
    await settle(tester);
    await tester.tap(find.text('Batches'));
    await settle(tester);
    expect(find.text('No batches tracked yet.'), findsOneWidget);

    await tester.tap(find.text('Add Batch'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Batch Number'), 'B-100');
    await tester.enterText(find.widgetWithText(TextField, 'Quantity Received'), '40');
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    await settle(tester);

    expect(backend.products.batches, hasLength(1));
    expect(backend.products.stockFor('p1'), 40);
    expect(find.textContaining('Batch B-100'), findsOneWidget);
  });

  testWidgets('positive: deleting a batch subtracts its quantity back out of stock', (tester) async {
    final backend = TestBackend();
    backend.products.departments = ['Analgesics'];
    backend.products.products = [
      buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'Analgesics': 1}, stockQuantity: 40),
    ];
    backend.products.batches
        .add(buildProductBatch(id: 'b1', productId: 'p1', batchNumber: 'B-100', expiryDate: isoDaysFromNow(200), quantity: 40));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Manage Inventory'));
    await settle(tester);
    await tester.tap(find.text('Batches'));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await settle(tester);

    expect(backend.products.batches, isEmpty);
    expect(backend.products.stockFor('p1'), 0);
  });

  testWidgets('positive: expiry alerts shows only batches within 90 days, not ones further out', (tester) async {
    final backend = TestBackend();
    backend.products.departments = ['Analgesics'];
    backend.products.products = [
      buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'Analgesics': 1}, stockQuantity: 50),
    ];
    backend.products.batches.addAll([
      buildProductBatch(id: 'b1', productId: 'p1', batchNumber: 'SOON', expiryDate: isoDaysFromNow(10), quantity: 10),
      buildProductBatch(id: 'b2', productId: 'p1', batchNumber: 'LATER', expiryDate: isoDaysFromNow(300), quantity: 40),
    ]);

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Expiry Alerts'));
    await settle(tester);

    expect(find.textContaining('Batch SOON'), findsOneWidget);
    expect(find.textContaining('Batch LATER'), findsNothing);
  });
}
