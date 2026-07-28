import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/product_repository.dart';
import '../../domain/models/product.dart';
import '../catalog/catalog_controller.dart';

/// Drives the admin product/department screens. Unlike [CatalogController]
/// (which only ever reads the local offline cache), this always reads and
/// writes Firestore directly — the admin needs to see and act on current
/// server data, not whatever this device last synced.
final adminCatalogControllerProvider =
    AsyncNotifierProvider<AdminCatalogController, CatalogSnapshot>(AdminCatalogController.new);

class AdminCatalogController extends AsyncNotifier<CatalogSnapshot> {
  @override
  Future<CatalogSnapshot> build() async {
    debugPrint('AdminCatalogController.build: fetching live catalog');
    final result = await ref.read(productRepositoryProvider).fetchLiveCatalog();
    debugPrint(
        'AdminCatalogController.build: fetch succeeded, departments=${result.departments.length} products=${result.products.length}');
    return result;
  }

  Future<void> refresh() async {
    debugPrint('AdminCatalogController.refresh: refreshing catalog');
    state = await AsyncValue.guard(() => ref.read(productRepositoryProvider).fetchLiveCatalog());
    debugPrint('AdminCatalogController.refresh: done, hasError=${state.hasError}');
  }

  Future<void> createProduct({
    required String name,
    required String info,
    required Map<String, int> departments,
    required String imageUrl,
    double unitPrice = 0,
  }) async {
    debugPrint('AdminCatalogController.createProduct: creating product name=$name');
    await ref.read(productRepositoryProvider).createProduct(
          name: name,
          info: info,
          departments: departments,
          imageUrl: imageUrl,
          unitPrice: unitPrice,
        );
    debugPrint('AdminCatalogController.createProduct: created product name=$name');
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> updateProduct(Product product) async {
    debugPrint('AdminCatalogController.updateProduct: updating product id=${product.id}');
    await ref.read(productRepositoryProvider).updateProduct(product);
    debugPrint('AdminCatalogController.updateProduct: updated product id=${product.id}');
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> deleteProduct(String id) async {
    debugPrint('AdminCatalogController.deleteProduct: deleting product id=$id');
    await ref.read(productRepositoryProvider).deleteProduct(id);
    debugPrint('AdminCatalogController.deleteProduct: deleted product id=$id');
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> addDepartment(String name) async {
    debugPrint('AdminCatalogController.addDepartment: adding department name=$name');
    await ref.read(productRepositoryProvider).addDepartment(name);
    debugPrint('AdminCatalogController.addDepartment: added department name=$name');
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> renameDepartment(String oldName, String newName) async {
    debugPrint('AdminCatalogController.renameDepartment: renaming $oldName -> $newName');
    await ref.read(productRepositoryProvider).renameDepartment(oldName, newName);
    debugPrint('AdminCatalogController.renameDepartment: renamed $oldName -> $newName');
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> deleteDepartment(String name) async {
    debugPrint('AdminCatalogController.deleteDepartment: deleting department name=$name');
    await ref.read(productRepositoryProvider).deleteDepartment(name);
    debugPrint('AdminCatalogController.deleteDepartment: deleted department name=$name');
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> adjustStock(String productId, int delta) async {
    debugPrint('AdminCatalogController.adjustStock: productId=$productId delta=$delta');
    await ref.read(productRepositoryProvider).adjustStock(productId, delta);
    debugPrint('AdminCatalogController.adjustStock: adjusted productId=$productId');
    await refresh();
    await _resyncDeviceCache();
  }

  /// Keeps this device's own offline catalog (used by the normal sales
  /// browsing screen) in step with whatever the admin just changed. Best
  /// effort: the admin action itself already succeeded even if this fails,
  /// so failures here are swallowed — the regular sync button still works
  /// as a fallback.
  Future<void> _resyncDeviceCache() async {
    debugPrint('AdminCatalogController._resyncDeviceCache: resyncing device cache');
    try {
      await ref.read(catalogControllerProvider.notifier).sync();
      debugPrint('AdminCatalogController._resyncDeviceCache: resync succeeded');
    } catch (error) {
      debugPrint('AdminCatalogController._resyncDeviceCache: resync failed error=$error');
      // Intentionally ignored — see doc comment above.
    }
  }
}
