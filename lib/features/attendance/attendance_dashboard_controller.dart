import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/usage_session.dart';
import '../team/team_access.dart';
import 'attendance_day.dart';

class AttendanceDashboardData {
  const AttendanceDashboardData({required this.employees, required this.daysByEmployee});

  final List<Employee> employees;
  final Map<String, List<AttendanceDay>> daysByEmployee;
}

final attendanceDashboardControllerProvider =
    AsyncNotifierProvider<AttendanceDashboardController, AttendanceDashboardData>(AttendanceDashboardController.new);

/// Joins employee profiles with their derived attendance (see
/// [deriveAttendanceDays]), same shape as [VisitLogDashboardController] —
/// reachable by the admin (sees everyone) and by any manager (sees just
/// their own reporting downline) via [resolveVisibleEmployees]. Reuses the
/// same [UsageSession] data the (separate) Usage Dashboard shows raw
/// sessions from — this is a derived summary of the same underlying
/// records, not a second data source.
class AttendanceDashboardController extends AsyncNotifier<AttendanceDashboardData> {
  @override
  Future<AttendanceDashboardData> build() async {
    debugPrint('AttendanceDashboardController.build: resolving visible employees');
    final employees = await resolveVisibleEmployees(ref);

    final isGlobal = ref.read(hasGlobalVisibilityProvider);
    final sessions = isGlobal
        ? await ref.read(usageSessionRepositoryProvider).fetchRecentForDashboard()
        : await ref.read(usageSessionRepositoryProvider).fetchRecentForEmployees(employees.map((e) => e.uid).toList());

    final sessionsByEmployee = <String, List<UsageSession>>{};
    for (final session in sessions) {
      sessionsByEmployee.putIfAbsent(session.employeeUid, () => []).add(session);
    }

    final daysByEmployee = {
      for (final employee in employees) employee.uid: deriveAttendanceDays(sessionsByEmployee[employee.uid] ?? const []),
    };

    return AttendanceDashboardData(employees: employees, daysByEmployee: daysByEmployee);
  }

  Future<void> refresh() async {
    debugPrint('AttendanceDashboardController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
