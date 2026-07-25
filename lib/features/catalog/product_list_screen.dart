import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import 'catalog_controller.dart';
import 'selection_controller.dart';
import 'widgets/category_section.dart';

/// Main catalog screen: products grouped by department, with multi-select
/// (feeding the slideshow) and a manual sync button to refresh from Firestore.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  bool _isSyncing = false;

  Future<void> _syncCatalog() async {
    setState(() => _isSyncing = true);

    String resultMessage;
    try {
      await ref.read(catalogControllerProvider.notifier).sync();
      resultMessage = 'Data synced successfully.';
    } catch (error) {
      // Deliberately don't rethrow: catalogControllerProvider keeps showing
      // whatever was last synced, so the user isn't left with a blank screen.
      resultMessage = 'Sync failed: $error';
    }

    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage)));
  }

  void _openSlideshowForSelection() {
    final selectedProducts = ref.read(selectionControllerProvider);
    if (selectedProducts.isEmpty) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: 'No Products Selected',
        text: 'Please select products to play the slideshow.',
      );
      return;
    }
    context.push('/slideshow', extra: selectedProducts);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bharath Biomed Pharma'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_sharp, size: 40),
            onPressed: _isSyncing ? null : _syncCatalog,
            color: Colors.green,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load catalog: $error')),
          data: (snapshot) {
            if (snapshot.departments.isEmpty) {
              return const Center(
                child: Text(
                  'No data synced yet.\nSign in and sync, or tap the sync button above, to download the catalog.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.builder(
              itemCount: snapshot.departments.length,
              itemBuilder: (context, index) {
                final department = snapshot.departments[index];
                final departmentProducts = snapshot.products
                    .where((product) => product.departments.containsKey(department))
                    .toList()
                  ..sort((a, b) => a.positionIn(department).compareTo(b.positionIn(department)));
                return CategorySection(category: department, products: departmentProducts);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSlideshowForSelection,
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
