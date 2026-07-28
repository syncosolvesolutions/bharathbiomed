import 'package:flutter/foundation.dart';

import '../../domain/models/doctor_visit_plan.dart';
import '../local/doctor_local_data_source.dart';
import '../remote/doctor_visit_plan_remote_data_source.dart';

/// An MR's weekly visiting schedule, offline-first: [loadCached] reads the
/// last-known plan without a network call; [save] writes to the local cache
/// immediately (so the UI reflects the edit right away even with no signal)
/// and best-effort pushes to Firestore, falling back to marking the cache
/// row unsynced so [pushUnsynced] (called from the evening sync) retries it.
class DoctorVisitPlanRepository {
  DoctorVisitPlanRepository({DoctorVisitPlanRemoteDataSource? remote, DoctorLocalDataSource? local})
      : _remote = remote ?? DoctorVisitPlanRemoteDataSource(),
        _local = local ?? DoctorLocalDataSource();

  final DoctorVisitPlanRemoteDataSource _remote;
  final DoctorLocalDataSource _local;

  Future<DoctorVisitPlan> loadCached(String mrUid) async {
    debugPrint('DoctorVisitPlanRepository.loadCached: mrUid=$mrUid');
    return await _local.getVisitPlan(mrUid) ?? DoctorVisitPlan(mrUid: mrUid);
  }

  /// Fetches the live plan from Firestore and refreshes the local cache —
  /// used when opening the plan screen with connectivity, so edits made from
  /// another device (or by the admin) aren't clobbered by a stale cache.
  Future<DoctorVisitPlan> sync(String mrUid) async {
    debugPrint('DoctorVisitPlanRepository.sync: mrUid=$mrUid');
    final plan = await _remote.fetch(mrUid);
    await _local.saveVisitPlan(plan, synced: true);
    return plan;
  }

  Future<void> save(DoctorVisitPlan plan) async {
    debugPrint('DoctorVisitPlanRepository.save: mrUid=${plan.mrUid}');
    try {
      await _remote.save(plan);
      await _local.saveVisitPlan(plan, synced: true);
    } catch (error) {
      debugPrint('DoctorVisitPlanRepository.save: remote save failed, caching offline error=$error');
      await _local.saveVisitPlan(plan, synced: false);
    }
  }

  /// Whether this MR's plan has an edit queued locally, waiting to reach
  /// Firestore — used by the sync prompt to know there's something to push.
  Future<bool> hasPendingUpload(String mrUid) => _local.hasUnsyncedVisitPlan(mrUid);

  Future<void> pushUnsynced(String mrUid) async {
    debugPrint('DoctorVisitPlanRepository.pushUnsynced: mrUid=$mrUid');
    if (!await _local.hasUnsyncedVisitPlan(mrUid)) return;
    final plan = await _local.getVisitPlan(mrUid);
    if (plan == null) return;
    await _remote.save(plan);
    await _local.markVisitPlanSynced(mrUid);
    debugPrint('DoctorVisitPlanRepository.pushUnsynced: pushed mrUid=$mrUid');
  }
}
