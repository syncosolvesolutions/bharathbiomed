import 'package:bharathbiomedpharma/domain/models/product.dart';
import 'package:bharathbiomedpharma/features/catalog/widgets/product_card.dart';
import 'package:bharathbiomedpharma/features/slideshow/slideshow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/harness.dart';

/// Catalog browsing/selection -> slideshow, and the empty-catalog state.
/// See docs/BUSINESS_OVERVIEW.md §2 ("Browse the catalog" / "Present").
void main() {
  Future<TestBackend> signedInMr(
    WidgetTester tester, {
    List<String> departments = const [],
    List<Product> products = const [],
  }) async {
    final backend = TestBackend();
    backend.employees.employees.add(buildEmployee(uid: 'mr1', username: 'rajesh_kumar'));
    backend.products.departments = departments;
    backend.products.products = products;
    await pumpApp(tester, backend: backend, signedInAs: buildFirebaseUser(uid: 'mr1', email: null));
    return backend;
  }

  testWidgets('positive: selecting products in tap order plays them back in that order, not catalog order', (tester) async {
    await signedInMr(
      tester,
      departments: ['Analgesics'],
      products: [
        buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'Analgesics': 0}),
        buildProduct(id: 'p2', name: 'Ibuprofen', departments: const {'Analgesics': 1}),
      ],
    );

    expect(find.text('Analgesics'), findsOneWidget);
    expect(find.byType(ProductCard), findsNWidgets(2));

    // Tap catalog-order-last product first, catalog-order-first product
    // second — the slideshow should preserve *this* order.
    await tester.tap(find.byWidgetPredicate((w) => w is ProductCard && w.product.id == 'p2'));
    await tester.pump();
    await tester.tap(find.byWidgetPredicate((w) => w is ProductCard && w.product.id == 'p1'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);

    final slideshow = tester.widget<SlideshowScreen>(find.byType(SlideshowScreen));
    expect(slideshow.selectedProducts.map((p) => p.id).toList(), ['p2', 'p1']);
  });

  testWidgets('edge: an empty catalog shows the "no data synced" state instead of crashing', (tester) async {
    await signedInMr(tester);

    expect(find.textContaining('No data synced yet'), findsOneWidget);
    expect(find.byType(ProductCard), findsNothing);
  });

  testWidgets('negative: playing with nothing selected shows a warning instead of opening the slideshow', (tester) async {
    await signedInMr(
      tester,
      departments: ['Analgesics'],
      products: [buildProduct(id: 'p1', name: 'Paracetamol', departments: const {'Analgesics': 0})],
    );

    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);

    expect(find.text('No Products Selected'), findsOneWidget);
    expect(find.byType(SlideshowScreen), findsNothing);
  });
}
