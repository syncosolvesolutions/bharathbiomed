import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:bharathbiomedpharma/features/admin/widgets/admin_product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Admin CRUD: departments, products, designations, and employees — all
/// admin-allowlist-only (see docs/BUSINESS_OVERVIEW.md §9.1). Product
/// *creation* needs a real photo picker this suite can't drive, so it's
/// covered only via the "image required" validation guard; editing an
/// already-photographed product (seeded with a non-empty `imageUrl`) is
/// fully covered instead.
void main() {
  const adminEmail = 'bharathbiomedpharma@gmail.com';

  testWidgets('positive: add, rename, then delete a department', (tester) async {
    final backend = TestBackend();
    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Manage Departments'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'New department name'), 'Analgesics');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await settle(tester);
    expect(backend.products.departments, ['Analgesics']);
    expect(find.text('Analgesics'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Pain Relief');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(backend.products.departments, ['Pain Relief']);

    await tester.tap(find.byIcon(Icons.delete));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await settle(tester);
    expect(backend.products.departments, isEmpty);
  });

  testWidgets('negative: adding a product with no photo is blocked', (tester) async {
    final backend = TestBackend();
    backend.products.departments = ['Analgesics'];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.text('Add Product'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Product Name'), 'Paracetamol');
    await tester.enterText(find.widgetWithText(TextFormField, 'Product Info'), '500mg tablet');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Product'));
    await settle(tester);

    expect(find.text('Image required'), findsOneWidget);
    expect(backend.products.products, isEmpty);
  });

  testWidgets('positive: edit an existing product\'s price, then delete it', (tester) async {
    final backend = TestBackend();
    backend.products.departments = ['Analgesics'];
    backend.products.products = [
      buildProduct(
        id: 'p1',
        name: 'Paracetamol',
        // Position 1, not 0 — `ProductFormScreen._save` treats a `<= 0`
        // position as "not really in this department" and strips it on
        // save, which would silently drop the product from Analgesics the
        // moment this edit form saves.
        departments: const {'Analgesics': 1},
        imageUrl: 'https://example.com/paracetamol.png',
        unitPrice: 5,
      ),
    ];

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.text('Analgesics'));
    await settle(tester);
    expect(find.byType(AdminProductTile), findsOneWidget);

    await tester.tap(find.byType(AdminProductTile));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Unit Price (optional)'), '7.5');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update Product'));
    await settle(tester);
    // The success QuickAlert's own confirm button also pops the screen.
    await tester.tap(find.text('Okay'));
    await settle(tester);
    expect(backend.products.products.single.unitPrice, 7.5);

    await tester.tap(find.descendant(of: find.byType(AdminProductTile), matching: find.byIcon(Icons.delete)));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await settle(tester);
    expect(backend.products.products, isEmpty);
  });

  testWidgets('positive: create a designation with a permission, then delete it', (tester) async {
    final backend = TestBackend();
    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Manage Designations'));
    await settle(tester);
    await tester.tap(find.byTooltip('Add designation'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Area Business Manager');
    await tester.tap(find.widgetWithText(CheckboxListTile, Permission.approveOrders.label));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Designation'));
    await settle(tester);

    expect(backend.designations.designations, hasLength(1));
    expect(backend.designations.designations.single.permissionSet, contains(Permission.approveOrders));
    expect(find.text('Area Business Manager'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await settle(tester);
    expect(backend.designations.designations, isEmpty);
  });

  testWidgets('positive: create an employee, then suspend and reactivate them', (tester) async {
    final backend = TestBackend();
    backend.designations.designations.add(buildDesignation(id: 'd1', name: 'Medical Representative'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Manage Employees'));
    await settle(tester);
    await tester.tap(find.text('Add Employee'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'First Name'), 'Rajesh');
    await tester.enterText(find.widgetWithText(TextFormField, 'Last Name'), 'Kumar');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Medical Representative').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Area / Territory'), 'North Zone');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'rajesh.kumar@example.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Employee'));
    await settle(tester);

    expect(find.text('Employee created'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Done')));
    await settle(tester);

    expect(backend.employees.employees, hasLength(1));
    expect(backend.employees.employees.single.username, 'rajesh_kumar');

    await tester.tap(find.byTooltip('Suspend'));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Suspend')));
    await settle(tester);
    expect(backend.employees.employees.single.disabled, isTrue);
    expect(find.text('Suspended'), findsOneWidget);

    await tester.tap(find.byTooltip('Reactivate'));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Reactivate')));
    await settle(tester);
    expect(backend.employees.employees.single.disabled, isFalse);
  });

  testWidgets('negative: creating an employee with a username already taken is rejected', (tester) async {
    final backend = TestBackend();
    backend.designations.designations.add(buildDesignation(id: 'd1', name: 'Medical Representative'));
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));

    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'admin1', email: adminEmail));
    await tester.tap(find.byTooltip('Manage Employees'));
    await settle(tester);
    await tester.tap(find.text('Add Employee'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'First Name'), 'Rajesh');
    await tester.enterText(find.widgetWithText(TextFormField, 'Last Name'), 'Kumar');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Medical Representative').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Area / Territory'), 'North Zone');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'rajesh.kumar@example.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Employee'));
    await settle(tester);

    expect(find.text('Failed to create employee'), findsOneWidget);
    expect(backend.employees.employees, hasLength(1));
  });
}
