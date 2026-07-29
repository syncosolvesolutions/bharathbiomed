import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/product_repository.dart';
import '../admin/admin_access.dart';
import '../agencies/agency_controller.dart';
import '../auth/auth_controller.dart';
import '../doctors/doctor_controller.dart';
import '../pharmacies/pharmacy_controller.dart';

/// Holds the catalog (products + departments) currently shown on screen.
final catalogControllerProvider = AsyncNotifierProvider<CatalogController, CatalogSnapshot>(CatalogController.new);

/// Reports progress after each step of [CatalogController.sync] finishes, so
/// a caller (see `features/sync/sync_controller.dart`) can show a percentage
/// instead of a bare spinner.
typedef SyncProgressCallback = void Function(int completed, int total, String label);

/// Drives the catalog screen. The app is offline-first, so [build] only ever
/// reads the local cache; [sync] is the single place that talks to Firestore,
/// triggered explicitly by the user (login screen, the sync button, or the
/// "new data available" sync prompt — see `features/sync/sync_controller.dart`).
class CatalogController extends AsyncNotifier<CatalogSnapshot> {
  @override
  Future<CatalogSnapshot> build() {
    debugPrint('CatalogController.build: loading cached catalog');
    return ref.read(productRepositoryProvider).loadCachedCatalog();
  }

  static const _totalSteps = 14;

  /// Downloads the latest catalog from Firestore and overwrites the local
  /// cache, then pushes every locally-queued offline record (usage sessions,
  /// doctor change requests, visit logs, an MR's visit plan) and refreshes
  /// the doctor list — both directions, in one call. Deliberately does NOT
  /// touch [state] on failure of the catalog step so a previously synced
  /// catalog stays on screen instead of being replaced by an error view —
  /// callers should catch and report the failure themselves. Every other
  /// step is best-effort: one failing must never block or mask the others.
  Future<void> sync({SyncProgressCallback? onProgress}) async {
    debugPrint('CatalogController.sync: starting catalog sync with Firestore');
    var completed = 0;
    void report(String label) => onProgress?.call(completed, _totalSteps, label);

    report('Downloading catalog…');
    final snapshot = await ref.read(productRepositoryProvider).sync();
    debugPrint('CatalogController.sync: catalog sync succeeded');
    state = AsyncData(snapshot);
    completed++;

    report('Uploading usage data…');
    try {
      debugPrint('CatalogController.sync: uploading pending usage sessions');
      await ref.read(usageSessionRepositoryProvider).uploadPending();
      debugPrint('CatalogController.sync: uploadPending succeeded');
    } catch (error) {
      debugPrint('CatalogController.sync: uploadPending failed error=$error');
    }
    completed++;

    report('Uploading doctor requests…');
    try {
      debugPrint('CatalogController.sync: uploading pending doctor change requests');
      await ref.read(doctorChangeRequestRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: doctor change request uploadPending failed error=$error');
    }
    completed++;

    report('Uploading visit logs…');
    try {
      debugPrint('CatalogController.sync: uploading pending doctor visit logs');
      await ref.read(doctorVisitLogRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: doctor visit log uploadPending failed error=$error');
    }
    completed++;

    report('Uploading visit plan…');
    final mrUid = ref.read(isAdminProvider) ? null : ref.read(authControllerProvider).value?.uid;
    if (mrUid != null) {
      try {
        debugPrint('CatalogController.sync: pushing unsynced visit plan');
        await ref.read(doctorVisitPlanRepositoryProvider).pushUnsynced(mrUid);
      } catch (error) {
        debugPrint('CatalogController.sync: visit plan pushUnsynced failed error=$error');
      }
    }
    completed++;

    report('Downloading doctor list…');
    try {
      debugPrint('CatalogController.sync: syncing doctor list');
      await ref.read(doctorControllerProvider.notifier).sync();
    } catch (error) {
      debugPrint('CatalogController.sync: doctor sync failed error=$error');
    }
    completed++;

    report('Uploading agency/pharmacy requests…');
    try {
      debugPrint('CatalogController.sync: uploading pending entity change requests');
      await ref.read(entityChangeRequestRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: entity change request uploadPending failed error=$error');
    }
    completed++;

    report('Downloading agencies…');
    try {
      debugPrint('CatalogController.sync: syncing agencies');
      await ref.read(agencyControllerProvider.notifier).sync();
    } catch (error) {
      debugPrint('CatalogController.sync: agency sync failed error=$error');
    }
    completed++;

    report('Downloading pharmacies…');
    try {
      debugPrint('CatalogController.sync: syncing pharmacies');
      await ref.read(pharmacyControllerProvider.notifier).sync();
    } catch (error) {
      debugPrint('CatalogController.sync: pharmacy sync failed error=$error');
    }
    completed++;

    report('Uploading orders…');
    try {
      debugPrint('CatalogController.sync: uploading pending orders');
      await ref.read(orderRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: order uploadPending failed error=$error');
    }
    completed++;

    report('Uploading RCPA entries…');
    try {
      debugPrint('CatalogController.sync: uploading pending RCPA entries');
      await ref.read(rcpaRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: RCPA uploadPending failed error=$error');
    }
    completed++;

    report('Uploading expense claims…');
    try {
      debugPrint('CatalogController.sync: uploading pending expense claims');
      await ref.read(expenseClaimRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: expense claim uploadPending failed error=$error');
    }
    completed++;

    report('Uploading leave requests…');
    try {
      debugPrint('CatalogController.sync: uploading pending leave requests');
      await ref.read(leaveRequestRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: leave request uploadPending failed error=$error');
    }
    completed++;

    report('Uploading compliance logs…');
    try {
      debugPrint('CatalogController.sync: uploading pending compliance logs');
      await ref.read(complianceLogRepositoryProvider).uploadPending();
    } catch (error) {
      debugPrint('CatalogController.sync: compliance log uploadPending failed error=$error');
    }
    completed++;

    onProgress?.call(completed, _totalSteps, 'Sync complete');
  }
}
