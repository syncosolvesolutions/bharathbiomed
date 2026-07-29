import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/doctor_visit_plan.dart';
import '../../domain/models/employee.dart';
import '../auth/auth_controller.dart';
import '../team/team_access.dart';

class VisitPlanApprovalData {
  const VisitPlanApprovalData({required this.employees, required this.plans});

  final List<Employee> employees;
  final List<DoctorVisitPlan> plans;
}

/// Weekly visit plans currently awaiting a decision, joined with employee
/// profiles for display (a plan doc only has an mrUid, no name — mirrors
/// [VisitLogDashboardController]'s `employees` + uid-keyed data shape).
/// Everyone's for a [hasGlobalVisibilityProvider] holder, just the
/// signed-in user's own reporting-chain downline otherwise (see
/// [resolveVisibleEmployees]).
final visitPlanApprovalControllerProvider =
    AsyncNotifierProvider<VisitPlanApprovalController, VisitPlanApprovalData>(VisitPlanApprovalController.new);

class VisitPlanApprovalController extends AsyncNotifier<VisitPlanApprovalData> {
  @override
  Future<VisitPlanApprovalData> build() async {
    debugPrint('VisitPlanApprovalController.build: resolving visible employees');
    final employees = await resolveVisibleEmployees(ref);

    final plans = ref.read(hasGlobalVisibilityProvider)
        ? await ref.read(doctorVisitPlanRepositoryProvider).fetchAllPending()
        : await ref
            .read(doctorVisitPlanRepositoryProvider)
            .fetchPendingForEmployees(employees.map((e) => e.uid).toList());

    return VisitPlanApprovalData(employees: employees, plans: plans);
  }

  Future<void> refresh() async {
    debugPrint('VisitPlanApprovalController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }

  /// `approve_requests`-gated in firestore.rules.
  Future<void> approve(String mrUid) async {
    debugPrint('VisitPlanApprovalController.approve: mrUid=$mrUid');
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    await ref.read(doctorVisitPlanRepositoryProvider).approve(mrUid, approvedByUid: uid);
    await refresh();
  }

  /// `approve_requests`-gated in firestore.rules.
  Future<void> reject(String mrUid, {String? reason}) async {
    debugPrint('VisitPlanApprovalController.reject: mrUid=$mrUid');
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    await ref.read(doctorVisitPlanRepositoryProvider).reject(mrUid, approvedByUid: uid, reason: reason);
    await refresh();
  }
}
