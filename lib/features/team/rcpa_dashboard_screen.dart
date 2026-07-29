import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/utils/report_export_service.dart';
import '../../core/widgets/export_menu_button.dart';
import '../admin/usage_format.dart';
import 'rcpa_dashboard_controller.dart';

/// Per-MR RCPA summary: how many entries logged and when they last logged
/// one. Tap through to see every logged entry for that employee. Mirrors
/// `VisitLogDashboardScreen`.
class RcpaDashboardScreen extends ConsumerStatefulWidget {
  const RcpaDashboardScreen({super.key});

  @override
  ConsumerState<RcpaDashboardScreen> createState() => _RcpaDashboardScreenState();
}

class _RcpaDashboardScreenState extends ConsumerState<RcpaDashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<List<String>> _rows(RcpaDashboardData dashboard) {
    final rows = <List<String>>[];
    for (final employee in dashboard.employees) {
      for (final entry in dashboard.entriesByEmployee[employee.uid] ?? const []) {
        rows.add([
          employee.displayName,
          entry.pharmacyName,
          entry.auditDate,
          entry.totalOwnBrandCount.toString(),
          entry.totalCompetitorCount.toString(),
          entry.notes,
        ]);
      }
    }
    return rows;
  }

  Future<void> _exportCsv(RcpaDashboardData dashboard) {
    return ref.read(reportExportServiceProvider).exportCsv(
          filename: 'rcpa_entries.csv',
          headers: const ['Employee', 'Pharmacy', 'Audit Date', 'Own Brand Scripts', 'Competitor Scripts', 'Notes'],
          rows: _rows(dashboard),
        );
  }

  Future<void> _exportPdf(RcpaDashboardData dashboard) {
    return ref.read(reportExportServiceProvider).exportSimpleTablePdf(
          filename: 'rcpa_entries.pdf',
          title: 'RCPA Entries',
          headers: const ['Employee', 'Pharmacy', 'Audit Date', 'Own Brand', 'Competitor', 'Notes'],
          rows: _rows(dashboard),
        );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(rcpaDashboardControllerProvider);
    final base = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RCPA Entries'),
        actions: [
          if (data.value != null)
            ExportMenuButton(
              onExportCsv: () => _exportCsv(data.value!),
              onExportPdf: () => _exportPdf(data.value!),
            ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load RCPA entries: ${UserFacingError.describe(error)}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(rcpaDashboardControllerProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (dashboard) {
          if (dashboard.employees.isEmpty) {
            return const Center(child: Text('No team members yet.'));
          }

          final query = _searchController.text.trim().toLowerCase();
          final employees = query.isEmpty
              ? dashboard.employees
              : dashboard.employees.where((e) => e.displayName.toLowerCase().contains(query)).toList();

          final sorted = List.of(employees)
            ..sort((a, b) {
              final aLast = dashboard.entriesByEmployee[a.uid]?.firstOrNull?.createdAt;
              final bLast = dashboard.entriesByEmployee[b.uid]?.firstOrNull?.createdAt;
              if (aLast == null && bLast == null) return 0;
              if (aLast == null) return 1;
              if (bLast == null) return -1;
              return bLast.compareTo(aLast);
            });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search employees',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: sorted.isEmpty
                    ? const Center(child: Text('No employees match this search.'))
                    : RefreshIndicator(
                        onRefresh: () => ref.read(rcpaDashboardControllerProvider.notifier).refresh(),
                        child: ListView.builder(
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final employee = sorted[index];
                            final entries = dashboard.entriesByEmployee[employee.uid] ?? const [];
                            final color = AccentPalette.forLabel(employee.displayName);
                            final last = entries.firstOrNull;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(alpha: 0.15),
                                  foregroundColor: color,
                                  child: Text(
                                      employee.displayName.isNotEmpty ? employee.displayName[0].toUpperCase() : '?'),
                                ),
                                title: Text(employee.displayName),
                                isThreeLine: true,
                                subtitle: RichText(
                                  text: TextSpan(
                                    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                                    children: [
                                      TextSpan(
                                        text: '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'} logged',
                                        style: TextStyle(color: color, fontWeight: FontWeight.w600),
                                      ),
                                      TextSpan(
                                        text: last == null
                                            ? '\nNo entries logged yet'
                                            : '\nLast: ${last.pharmacyName} • ${formatDateTime(last.createdAt)}',
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => context.push('$base/detail', extra: employee),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
