import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/order.dart';
import '../../domain/models/sales_target.dart';
import '../team/team_access.dart';
import 'target_progress.dart';

class EmployeeTargetProgress {
  const EmployeeTargetProgress({required this.employee, required this.progress});

  final Employee employee;
  final TargetProgress progress;
}

/// Current-month target vs. achievement for the signed-in user's own
/// reporting-chain downline (or everyone, for a global-visibility holder) —
/// see [resolveVisibleEmployees]. One order fetch per employee is simple but
/// fine at this app's expected team sizes; mirrors the same reasoning as
/// [OrderApprovalController]'s per-scope fetch.
final teamTargetsControllerProvider =
    AsyncNotifierProvider<TeamTargetsController, List<EmployeeTargetProgress>>(TeamTargetsController.new);

class TeamTargetsController extends AsyncNotifier<List<EmployeeTargetProgress>> {
  @override
  Future<List<EmployeeTargetProgress>> build() async {
    final period = currentTargetPeriod();
    debugPrint('TeamTargetsController.build: resolving visible employees for period=$period');
    final employees = await resolveVisibleEmployees(ref);
    if (employees.isEmpty) return [];

    final uids = employees.map((e) => e.uid).toList();
    final targets = await ref.read(salesTargetRepositoryProvider).fetchForEmployees(uids, period);
    final targetsByUid = {for (final target in targets) target.employeeUid: target};
    final orders = await ref.read(orderRepositoryProvider).fetchForEmployees(uids);
    final ordersByUid = <String, List<Order>>{};
    for (final order in orders) {
      ordersByUid.putIfAbsent(order.createdByUid, () => []).add(order);
    }

    return employees.map((employee) {
      final employeeOrders = ordersByUid[employee.uid] ?? const [];
      final achievement = achievementForPeriod(employeeOrders, period);
      return EmployeeTargetProgress(
        employee: employee,
        progress: TargetProgress(period: period, target: targetsByUid[employee.uid], achievement: achievement),
      );
    }).toList();
  }

  Future<void> refresh() async {
    debugPrint('TeamTargetsController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
