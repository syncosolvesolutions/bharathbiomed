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
  Future<CatalogSnapshot> build() {
    return ref.read(productRepositoryProvider).fetchLiveCatalog();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(productRepositoryProvider).fetchLiveCatalog());
  }

  Future<void> createProduct({
    required String name,
    required String info,
    required Map<String, int> departments,
    required String imageUrl,
  }) async {
    await ref.read(productRepositoryProvider).createProduct(
          name: name,
          info: info,
          departments: departments,
          imageUrl: imageUrl,
        );
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> updateProduct(Product product) async {
    await ref.read(productRepositoryProvider).updateProduct(product);
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> deleteProduct(String id) async {
    await ref.read(productRepositoryProvider).deleteProduct(id);
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> addDepartment(String name) async {
    await ref.read(productRepositoryProvider).addDepartment(name);
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> renameDepartment(String oldName, String newName) async {
    await ref.read(productRepositoryProvider).renameDepartment(oldName, newName);
    await refresh();
    await _resyncDeviceCache();
  }

  Future<void> deleteDepartment(String name) async {
    await ref.read(productRepositoryProvider).deleteDepartment(name);
    await refresh();
    await _resyncDeviceCache();
  }

  /// Keeps this device's own offline catalog (used by the normal sales
  /// browsing screen) in step with whatever the admin just changed. Best
  /// effort: the admin action itself already succeeded even if this fails,
  /// so failures here are swallowed — the regular sync button still works
  /// as a fallback.
  Future<void> _resyncDeviceCache() async {
    try {
      await ref.read(catalogControllerProvider.notifier).sync();
    } catch (_) {
      // Intentionally ignored — see doc comment above.
    }
  }
}
