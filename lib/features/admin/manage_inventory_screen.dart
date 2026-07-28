import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../domain/models/product.dart';
import 'admin_catalog_controller.dart';

/// Stock levels for every product, with a quick "adjust by" action per row
/// (e.g. +50 for a shipment received, -5 for a correction) — see
/// [Product.stockQuantity] and [AdminCatalogController.adjustStock]. A
/// dispatched order decrements stock automatically (via the `dispatchOrder`
/// Cloud Function); this screen is for everything else.
class ManageInventoryScreen extends ConsumerStatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  ConsumerState<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends ConsumerState<ManageInventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applySearch(List<Product> products) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((product) => product.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _adjust(Product product) async {
    final controller = TextEditingController();
    final delta = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust stock — ${product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(
            labelText: 'Change amount',
            helperText: 'Positive to add (e.g. 50 received), negative to subtract (e.g. -5 correction).',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (delta == null || delta == 0) return;

    try {
      await ref.read(adminCatalogControllerProvider.notifier).adjustStock(product.id, delta);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Stock ${delta > 0 ? 'increased' : 'decreased'} by ${delta.abs()}.')));
    } catch (error, stackTrace) {
      AppLogger.error('ManageInventory', 'adjustStock failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(adminCatalogControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Inventory')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search products',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: catalog.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(UserFacingError.describe(error))),
                data: (snapshot) {
                  final filtered = _applySearch(snapshot.products);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No products match this search.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      final color = AccentPalette.forLabel(product.name);
                      final low = product.stockQuantity <= 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          foregroundColor: color,
                          child: Text(product.name.isNotEmpty ? product.name[0].toUpperCase() : '?'),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.stockQuantity} in stock',
                          style: low ? const TextStyle(color: Colors.red, fontWeight: FontWeight.w600) : null,
                        ),
                        trailing: TextButton(
                          onPressed: () => _adjust(product),
                          child: const Text('Adjust'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
