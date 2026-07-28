import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/entity_change_request.dart';
import '../agencies/agency_controller.dart';
import '../pharmacies/pharmacy_controller.dart';

/// Pending agency/pharmacy create requests awaiting Office Admin review —
/// mirrors [DoctorRequestsController]. Always talks to Firestore directly;
/// an Office Admin reviewing requests is assumed to be online.
final entityRequestsControllerProvider =
    AsyncNotifierProvider<EntityRequestsController, List<EntityChangeRequest>>(EntityRequestsController.new);

class EntityRequestsController extends AsyncNotifier<List<EntityChangeRequest>> {
  @override
  Future<List<EntityChangeRequest>> build() {
    debugPrint('EntityRequestsController.build: fetching pending requests');
    return ref.read(entityChangeRequestRepositoryProvider).fetchPending();
  }

  Future<void> review(String requestId, {required bool approve, String? reviewNote}) async {
    debugPrint('EntityRequestsController.review: requestId=$requestId approve=$approve');
    await ref
        .read(entityChangeRequestRepositoryProvider)
        .review(requestId, approve: approve, reviewNote: reviewNote);
    state = await AsyncValue.guard(() => ref.read(entityChangeRequestRepositoryProvider).fetchPending());
    // An approval just changed what's in Agencies/Pharmacies — keep both
    // cached lists from looking stale if the reviewer navigates to them next.
    // Best-effort: a failure here shouldn't mask the review itself succeeding.
    try {
      await ref.read(agencyControllerProvider.notifier).sync();
    } catch (error) {
      debugPrint('EntityRequestsController.review: agency re-sync failed error=$error');
    }
    try {
      await ref.read(pharmacyControllerProvider.notifier).sync();
    } catch (error) {
      debugPrint('EntityRequestsController.review: pharmacy re-sync failed error=$error');
    }
  }
}
