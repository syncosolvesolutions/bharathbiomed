import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/tenant_config.dart';
import '../../data/providers.dart';
import '../../domain/models/compliance_log.dart';
import '../team/team_access.dart';

/// One doctor's cumulative compliance value across every MR who's logged
/// something for them, for the current calendar year — the actual UCPMP
/// question is "has this doctor received too much," not "has this one MR
/// given too much," so this aggregates by doctor, not by MR (contrast
/// [VisitLogDashboardController]/[RcpaDashboardController], which are
/// per-employee).
class DoctorComplianceSummary {
  const DoctorComplianceSummary({
    required this.doctorId,
    required this.doctorName,
    required this.totalValue,
    required this.entryCount,
  });

  final String doctorId;
  final String doctorName;
  final double totalValue;
  final int entryCount;

  bool get isOverLimit => totalValue > currentTenant.ucpmpAnnualLimitPerDoctor;
}

final complianceDashboardControllerProvider =
    AsyncNotifierProvider<ComplianceDashboardController, List<DoctorComplianceSummary>>(
        ComplianceDashboardController.new);

/// Reachable by the admin (sees everyone) and by any manager (sees just
/// their own reporting downline) via [resolveVisibleEmployees] — same
/// scoping as every other team dashboard in this app.
class ComplianceDashboardController extends AsyncNotifier<List<DoctorComplianceSummary>> {
  @override
  Future<List<DoctorComplianceSummary>> build() async {
    debugPrint('ComplianceDashboardController.build: resolving visible employees');
    final isGlobal = ref.read(hasGlobalVisibilityProvider);
    final logs = isGlobal
        ? await ref.read(complianceLogRepositoryProvider).fetchRecentForDashboard()
        : await ref
            .read(complianceLogRepositoryProvider)
            .fetchRecentForEmployees((await resolveVisibleEmployees(ref)).map((e) => e.uid).toList());

    final currentYear = DateTime.now().year;
    final thisYearsLogs = logs.where((log) => log.createdAt.year == currentYear);

    final byDoctor = <String, List<ComplianceLog>>{};
    for (final log in thisYearsLogs) {
      byDoctor.putIfAbsent(log.doctorId, () => []).add(log);
    }

    final summaries = byDoctor.entries.map((entry) {
      final doctorLogs = entry.value;
      final total = doctorLogs.fold<double>(0, (sum, log) => sum + log.value);
      return DoctorComplianceSummary(
        doctorId: entry.key,
        doctorName: doctorLogs.first.doctorName,
        totalValue: total,
        entryCount: doctorLogs.length,
      );
    }).toList();

    summaries.sort((a, b) => b.totalValue.compareTo(a.totalValue));
    return summaries;
  }

  Future<void> refresh() async {
    debugPrint('ComplianceDashboardController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
