import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/product_repository.dart';

/// Holds the catalog (products + departments) currently shown on screen.
final catalogControllerProvider = AsyncNotifierProvider<CatalogController, CatalogSnapshot>(CatalogController.new);

/// Drives the catalog screen. The app is offline-first, so [build] only ever
/// reads the local cache; [sync] is the single place that talks to Firestore,
/// triggered explicitly by the user (login screen or the sync button).
class CatalogController extends AsyncNotifier<CatalogSnapshot> {
  @override
  Future<CatalogSnapshot> build() {
    return ref.read(productRepositoryProvider).loadCachedCatalog();
  }

  /// Downloads the latest catalog from Firestore and overwrites the local
  /// cache. Deliberately does NOT touch [state] on failure so a previously
  /// synced catalog stays on screen instead of being replaced by an error
  /// view — callers should catch and report the failure themselves.
  Future<void> sync() async {
    final snapshot = await ref.read(productRepositoryProvider).sync();
    state = AsyncData(snapshot);
  }
}
