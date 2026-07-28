import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/doctor_visit_log.dart';
import '../../domain/models/employee.dart';
import 'team_access.dart';

class VisitLogDashboardData {
  const VisitLogDashboardData({required this.employees, required this.logsByEmployee});

  final List<Employee> employees;
  final Map<String, List<DoctorVisitLog>> logsByEmployee;
}

final visitLogDashboardControllerProvider =
    AsyncNotifierProvider<VisitLogDashboardController, VisitLogDashboardData>(VisitLogDashboardController.new);

/// Joins employee profiles with their uploaded doctor visit logs, the same
/// way [UsageDashboardController] does for usage sessions — reachable by the
/// admin (sees everyone) and by any manager (sees just their own reporting
/// downline) via [resolveVisibleEmployees]. Wires up
/// `DoctorVisitLogRepository.fetchRecentForDashboard`/`fetchRecentForEmployees`,
/// which previously had no screen calling them at all.
class VisitLogDashboardController extends AsyncNotifier<VisitLogDashboardData> {
  @override
  Future<VisitLogDashboardData> build() async {
    debugPrint('VisitLogDashboardController.build: resolving visible employees');
    final employees = await resolveVisibleEmployees(ref);
    debugPrint('VisitLogDashboardController.build: resolved ${employees.length} employees');

    final isGlobal = ref.read(hasGlobalVisibilityProvider);
    debugPrint('VisitLogDashboardController.build: fetching recent visit logs isGlobal=$isGlobal');
    final logs = isGlobal
        ? await ref.read(doctorVisitLogRepositoryProvider).fetchRecentForDashboard()
        : await ref.read(doctorVisitLogRepositoryProvider).fetchRecentForEmployees(employees.map((e) => e.uid).toList());
    debugPrint('VisitLogDashboardController.build: fetched ${logs.length} logs');

    final logsByEmployee = <String, List<DoctorVisitLog>>{};
    for (final log in logs) {
      logsByEmployee.putIfAbsent(log.mrUid, () => []).add(log);
    }
    for (final entry in logsByEmployee.values) {
      entry.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return VisitLogDashboardData(employees: employees, logsByEmployee: logsByEmployee);
  }

  Future<void> refresh() async {
    debugPrint('VisitLogDashboardController.refresh: refreshing visit log dashboard');
    state = await AsyncValue.guard(build);
    debugPrint('VisitLogDashboardController.refresh: done, hasError=${state.hasError}');
  }
}
