import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/rcpa_entry.dart';
import 'team_access.dart';

class RcpaDashboardData {
  const RcpaDashboardData({required this.employees, required this.entriesByEmployee});

  final List<Employee> employees;
  final Map<String, List<RcpaEntry>> entriesByEmployee;
}

final rcpaDashboardControllerProvider =
    AsyncNotifierProvider<RcpaDashboardController, RcpaDashboardData>(RcpaDashboardController.new);

/// Joins employee profiles with their uploaded RCPA entries — mirrors
/// [VisitLogDashboardController] exactly, wiring up
/// `RcpaRepository.fetchRecentForDashboard`/`fetchRecentForEmployees` to a
/// real screen for whoever manages this MR's reporting chain.
class RcpaDashboardController extends AsyncNotifier<RcpaDashboardData> {
  @override
  Future<RcpaDashboardData> build() async {
    debugPrint('RcpaDashboardController.build: resolving visible employees');
    final employees = await resolveVisibleEmployees(ref);
    debugPrint('RcpaDashboardController.build: resolved ${employees.length} employees');

    final isGlobal = ref.read(hasGlobalVisibilityProvider);
    final entries = isGlobal
        ? await ref.read(rcpaRepositoryProvider).fetchRecentForDashboard()
        : await ref.read(rcpaRepositoryProvider).fetchRecentForEmployees(employees.map((e) => e.uid).toList());

    final entriesByEmployee = <String, List<RcpaEntry>>{};
    for (final entry in entries) {
      entriesByEmployee.putIfAbsent(entry.mrUid, () => []).add(entry);
    }
    for (final list in entriesByEmployee.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return RcpaDashboardData(employees: employees, entriesByEmployee: entriesByEmployee);
  }

  Future<void> refresh() async {
    debugPrint('RcpaDashboardController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
