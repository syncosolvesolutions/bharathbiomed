import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/usage_session.dart';
import '../team/team_access.dart';

class EmployeeUsageSummary {
  const EmployeeUsageSummary({
    required this.employee,
    required this.sessionCount,
    required this.totalDuration,
    this.lastOpenedAt,
    this.lastLatitude,
    this.lastLongitude,
  });

  final Employee employee;
  final int sessionCount;
  final Duration totalDuration;
  final DateTime? lastOpenedAt;
  final double? lastLatitude;
  final double? lastLongitude;

  bool get hasLastLocation => lastLatitude != null && lastLongitude != null;
}

class UsageDashboardData {
  const UsageDashboardData({required this.summaries, required this.sessionsByEmployee});

  final List<EmployeeUsageSummary> summaries;
  final Map<String, List<UsageSession>> sessionsByEmployee;
}

final usageDashboardControllerProvider =
    AsyncNotifierProvider<UsageDashboardController, UsageDashboardData>(UsageDashboardController.new);

/// Joins employee profiles with their uploaded usage sessions (both fetched
/// live from Firestore) into per-employee summaries for the dashboard, plus
/// the full per-employee session list for drill-down. Reachable by the
/// admin (sees everyone) and by any manager (sees just their own reporting
/// downline) — see [resolveVisibleEmployees].
class UsageDashboardController extends AsyncNotifier<UsageDashboardData> {
  @override
  Future<UsageDashboardData> build() async {
    debugPrint('UsageDashboardController.build: resolving visible employees');
    final employees = await resolveVisibleEmployees(ref);
    debugPrint('UsageDashboardController.build: resolved ${employees.length} employees');

    final isGlobal = ref.read(hasGlobalVisibilityProvider);
    debugPrint('UsageDashboardController.build: fetching recent usage sessions isGlobal=$isGlobal');
    final sessions = isGlobal
        ? await ref.read(usageSessionRepositoryProvider).fetchRecentForDashboard()
        : await ref.read(usageSessionRepositoryProvider).fetchRecentForEmployees(employees.map((e) => e.uid).toList());
    debugPrint('UsageDashboardController.build: fetched ${sessions.length} sessions');

    final sessionsByEmployee = <String, List<UsageSession>>{};
    for (final session in sessions) {
      sessionsByEmployee.putIfAbsent(session.employeeUid, () => []).add(session);
    }

    final summaries = employees.map((employee) {
      final employeeSessions = List.of(sessionsByEmployee[employee.uid] ?? const <UsageSession>[])
        ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
      final totalDuration = employeeSessions.fold<Duration>(
        Duration.zero,
        (sum, session) => sum + (session.duration ?? Duration.zero),
      );
      final last = employeeSessions.isEmpty ? null : employeeSessions.first;

      return EmployeeUsageSummary(
        employee: employee,
        sessionCount: employeeSessions.length,
        totalDuration: totalDuration,
        lastOpenedAt: last?.openedAt,
        lastLatitude: last?.latitude,
        lastLongitude: last?.longitude,
      );
    }).toList();

    final never = DateTime.fromMillisecondsSinceEpoch(0);
    summaries.sort((a, b) => (b.lastOpenedAt ?? never).compareTo(a.lastOpenedAt ?? never));

    return UsageDashboardData(summaries: summaries, sessionsByEmployee: sessionsByEmployee);
  }

  Future<void> refresh() async {
    debugPrint('UsageDashboardController.refresh: refreshing usage dashboard');
    state = await AsyncValue.guard(build);
    debugPrint('UsageDashboardController.refresh: done, hasError=${state.hasError}');
  }
}
