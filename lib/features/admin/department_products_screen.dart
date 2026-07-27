import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../domain/models/product.dart';
import 'admin_catalog_controller.dart';
import 'widgets/admin_product_tile.dart';

/// Grid of products within one department, with tap-to-edit and per-tile
/// delete — the admin equivalent of the sales app's [CategorySection].
class DepartmentProductsScreen extends ConsumerStatefulWidget {
  const DepartmentProductsScreen({super.key, required this.department});

  final String department;

  @override
  ConsumerState<DepartmentProductsScreen> createState() => _DepartmentProductsScreenState();
}

class _DepartmentProductsScreenState extends ConsumerState<DepartmentProductsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteProduct(BuildContext context, WidgetRef ref, Product product) async {
    try {
      await ref.read(adminCatalogControllerProvider.notifier).deleteProduct(product.id);
    } catch (error) {
      if (!context.mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Delete failed',
        text: UserFacingError.describe(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(adminCatalogControllerProvider);
    final accent = AccentPalette.forLabel(widget.department);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 14,
              // Solid white (not an alpha-blended tint) so this stays legible
              // regardless of what's behind it — the app bar is now a solid
              // brand-blue, not the near-white surface this used to blend
              // against.
              backgroundColor: Colors.white,
              foregroundColor: accent,
              child: Text(
                widget.department.isNotEmpty ? widget.department[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.department),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search products',
                prefixIcon: Icon(Icons.search, color: accent),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load products: ${UserFacingError.describe(error)}')),
              data: (snapshot) {
                final query = _searchController.text.trim().toLowerCase();
                final products = snapshot.products
                    .where((p) => p.departments.containsKey(widget.department))
                    .where((p) => query.isEmpty || p.name.toLowerCase().contains(query))
                    .toList()
                  ..sort((a, b) => a.positionIn(widget.department).compareTo(b.positionIn(widget.department)));

                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      query.isEmpty ? 'No products in this department yet.' : 'No products match this search.',
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8.0,
                    crossAxisSpacing: 8.0,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return AdminProductTile(
                      product: product,
                      onTap: () => context.push('/admin/products/edit', extra: product),
                      onDelete: () => _deleteProduct(context, ref, product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
