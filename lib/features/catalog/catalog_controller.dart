import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/product_repository.dart';
import '../doctors/doctor_controller.dart';

/// Holds the catalog (products + departments) currently shown on screen.
final catalogControllerProvider = AsyncNotifierProvider<CatalogController, CatalogSnapshot>(CatalogController.new);

/// Drives the catalog screen. The app is offline-first, so [build] only ever
/// reads the local cache; [sync] is the single place that talks to Firestore,
/// triggered explicitly by the user (login screen or the sync button).
class CatalogController extends AsyncNotifier<CatalogSnapshot> {
  @override
  Future<CatalogSnapshot> build() {
    debugPrint('CatalogController.build: loading cached catalog');
    return ref.read(productRepositoryProvider).loadCachedCatalog();
  }

  /// Downloads the latest catalog from Firestore and overwrites the local
  /// cache. Deliberately does NOT touch [state] on failure so a previously
  /// synced catalog stays on screen instead of being replaced by an error
  /// view — callers should catch and report the failure themselves.
  Future<void> sync() async {
    debugPrint('CatalogController.sync: starting catalog sync with Firestore');
    final snapshot = await ref.read(productRepositoryProvider).sync();
    debugPrint('CatalogController.sync: catalog sync succeeded');
    state = AsyncData(snapshot);

    // Best-effort: this is the one point this app talks to the server
    // without the user having explicitly asked for *this* — piggybacking on
    // an action they did explicitly ask for (sync) rather than uploading on
    // its own whenever connectivity appears. A failure here must never mask
    // the catalog sync succeeding.
    try {
      debugPrint('CatalogController.sync: uploading pending usage sessions');
      await ref.read(usageSessionRepositoryProvider).uploadPending();
      debugPrint('CatalogController.sync: uploadPending succeeded');
    } catch (error) {
      debugPrint('CatalogController.sync: uploadPending failed error=$error');
      // Intentionally ignored — see comment above.
    }

    // Same best-effort treatment for the doctors feature's offline queue —
    // this is the "sync everything in the evening" button (requirement
    // 11/12), so it should also push whatever an MR queued locally today
    // (doctor create/edit requests, visit/feedback logs) and refresh their
    // assigned-doctors cache, without letting any one of those steps block
    // or fail the others.
    try {
      debugPrint('CatalogController.sync: uploading pending doctor change requests');
      await ref.read(doctorChangeRequestRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: doctor change request uploadPending failed error=$error');
    }
    try {
      debugPrint('CatalogController.sync: uploading pending doctor visit logs');
      await ref.read(doctorVisitLogRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: doctor visit log uploadPending failed error=$error');
    }
    try {
      debugPrint('CatalogController.sync: syncing doctor list');
      await ref.read(doctorControllerProvider.notifier).sync();
    } catch (error) {
      debugPrint('CatalogController.sync: doctor sync failed error=$error');
    }
  }
}
