import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/report_export_service.dart';
import '../../core/widgets/export_menu_button.dart';
import 'usage_dashboard_controller.dart';
import 'usage_format.dart';

/// Per-MR summary: session count, total time in the app, and when/where
/// they last opened it. Tap through to see every recorded session for that
/// employee. See docs/BUSINESS_OVERVIEW.md for what this data means and how
/// it's collected.
class UsageDashboardScreen extends ConsumerStatefulWidget {
  const UsageDashboardScreen({super.key});

  @override
  ConsumerState<UsageDashboardScreen> createState() => _UsageDashboardScreenState();
}

class _UsageDashboardScreenState extends ConsumerState<UsageDashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    debugPrint('UsageDashboardScreen.dispose: disposing');
    _searchController.dispose();
    super.dispose();
  }

  List<List<String>> _rows(UsageDashboardData dashboard) => dashboard.summaries
      .map((summary) => [
            summary.employee.displayName,
            summary.sessionCount.toString(),
            formatDuration(summary.totalDuration),
            summary.lastOpenedAt == null ? 'Never' : formatDateTime(summary.lastOpenedAt!),
          ])
      .toList();

  Future<void> _exportCsv(UsageDashboardData dashboard) {
    return ref.read(reportExportServiceProvider).exportCsv(
          filename: 'usage_dashboard.csv',
          headers: const ['Employee', 'Sessions', 'Total Time', 'Last Opened'],
          rows: _rows(dashboard),
        );
  }

  Future<void> _exportPdf(UsageDashboardData dashboard) {
    return ref.read(reportExportServiceProvider).exportSimpleTablePdf(
          filename: 'usage_dashboard.pdf',
          title: 'Usage Dashboard',
          headers: const ['Employee', 'Sessions', 'Total Time', 'Last Opened'],
          rows: _rows(dashboard),
        );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(usageDashboardControllerProvider);
    // Reachable at both /admin/dashboard (admin) and /team/usage (a manager
    // without the admin allowlist) — push relative to whichever base this
    // instance was reached through instead of hardcoding one.
    final base = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Dashboard'),
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
              Text('Failed to load usage data: ${UserFacingError.describe(error)}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  debugPrint('UsageDashboardScreen: retry button tapped');
                  ref.read(usageDashboardControllerProvider.notifier).refresh();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (dashboard) {
          if (dashboard.summaries.isEmpty) {
            return const Center(child: Text('No employees yet.'));
          }

          final query = _searchController.text.trim().toLowerCase();
          final summaries = query.isEmpty
              ? dashboard.summaries
              : dashboard.summaries.where((summary) {
                  final employee = summary.employee;
                  return employee.displayName.toLowerCase().contains(query) ||
                      employee.username.toLowerCase().contains(query) ||
                      employee.areaName.toLowerCase().contains(query);
                }).toList();

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
                child: summaries.isEmpty
                    ? const Center(child: Text('No employees match this search.'))
                    : RefreshIndicator(
                        onRefresh: () {
                          debugPrint('UsageDashboardScreen: pull-to-refresh triggered');
                          return ref.read(usageDashboardControllerProvider.notifier).refresh();
                        },
                        child: ListView.builder(
                          itemCount: summaries.length,
                          itemBuilder: (context, index) {
                            final summary = summaries[index];
                            final color = AccentPalette.forLabel(summary.employee.displayName);
                            final name = summary.employee.displayName;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(alpha: 0.15),
                                  foregroundColor: color,
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                                ),
                                title: Text(name),
                                isThreeLine: true,
                                subtitle: RichText(
                                  text: TextSpan(
                                    style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                                    children: [
                                      TextSpan(
                                        text: '${summary.sessionCount} session${summary.sessionCount == 1 ? '' : 's'}',
                                        style: TextStyle(color: color, fontWeight: FontWeight.w600),
                                      ),
                                      const TextSpan(text: ' • '),
                                      TextSpan(
                                        text: '${formatDuration(summary.totalDuration)} total',
                                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
                                      ),
                                      TextSpan(
                                        text:
                                            '\n${summary.lastOpenedAt == null ? 'Never opened' : 'Last opened: ${formatDateTime(summary.lastOpenedAt!)}'}',
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => context.push('$base/sessions', extra: summary.employee),
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
