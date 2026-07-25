import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/product.dart';
import '../selection_controller.dart';
import 'product_card.dart';

/// One department's horizontally-scrolling row of [ProductCard]s, sorted by
/// each product's position within this department.
class CategorySection extends ConsumerWidget {
  const CategorySection({super.key, required this.category, required this.products});

  final String category;
  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            category,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              final product = products[i];
              final selectedIndex = selection.indexOf(product);
              return ProductCard(
                product: product,
                selectionNumber: selectedIndex >= 0 ? selectedIndex + 1 : 0,
              );
            },
          ),
        ),
      ],
    );
  }
}
