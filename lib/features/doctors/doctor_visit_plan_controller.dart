import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/doctor_visit_plan.dart';
import '../auth/auth_controller.dart';

/// The signed-in MR's own weekly visit plan (requirement 13/14). [build]
/// reads whatever's cached locally so the plan screen works offline;
/// [sync] pulls the live doc down (e.g. in case the admin adjusted it, or
/// this MR edited it from another device); [toggleDoctor] flips one doctor
/// on/off for one weekday and saves immediately.
final doctorVisitPlanControllerProvider =
    AsyncNotifierProvider<DoctorVisitPlanController, DoctorVisitPlan>(DoctorVisitPlanController.new);

class DoctorVisitPlanController extends AsyncNotifier<DoctorVisitPlan> {
  String get _mrUid => ref.read(authControllerProvider).value?.uid ?? '';

  @override
  Future<DoctorVisitPlan> build() {
    debugPrint('DoctorVisitPlanController.build: loading cached plan');
    return ref.read(doctorVisitPlanRepositoryProvider).loadCached(_mrUid);
  }

  Future<void> sync() async {
    debugPrint('DoctorVisitPlanController.sync: syncing plan');
    state = await AsyncValue.guard(() => ref.read(doctorVisitPlanRepositoryProvider).sync(_mrUid));
  }

  Future<void> toggleDoctor(String weekdayKey, String doctorId) async {
    final current = state.value ?? DoctorVisitPlan(mrUid: _mrUid);
    final existing = List<String>.from(current.forWeekday(weekdayKey));
    if (existing.contains(doctorId)) {
      existing.remove(doctorId);
    } else {
      existing.add(doctorId);
    }
    final updated = current.copyWithWeekday(weekdayKey, existing);
    state = AsyncData(updated);
    debugPrint('DoctorVisitPlanController.toggleDoctor: weekday=$weekdayKey doctorId=$doctorId');
    await ref.read(doctorVisitPlanRepositoryProvider).save(updated);
  }

  /// Submits the current plan for manager approval — see
  /// [DoctorVisitPlanRepository.submitForApproval]. Needs connectivity;
  /// callers should catch and report a failure themselves (see
  /// `VisitPlanScreen`'s submit button).
  Future<void> submitForApproval() async {
    debugPrint('DoctorVisitPlanController.submitForApproval: mrUid=$_mrUid');
    final updated = await ref.read(doctorVisitPlanRepositoryProvider).submitForApproval(_mrUid);
    state = AsyncData(updated);
  }
}
