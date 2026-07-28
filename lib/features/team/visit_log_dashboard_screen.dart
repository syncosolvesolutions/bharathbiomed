import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../admin/usage_format.dart';
import 'visit_log_dashboard_controller.dart';

/// Per-MR visit-log summary: how many doctor visits they've logged and when
/// they last logged one. Tap through to see every logged visit for that
/// employee. Mirrors `UsageDashboardScreen`'s structure.
class VisitLogDashboardScreen extends ConsumerStatefulWidget {
  const VisitLogDashboardScreen({super.key});

  @override
  ConsumerState<VisitLogDashboardScreen> createState() => _VisitLogDashboardScreenState();
}

class _VisitLogDashboardScreenState extends ConsumerState<VisitLogDashboardScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(visitLogDashboardControllerProvider);
    final base = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('Visit Logs')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load visit logs: ${UserFacingError.describe(error)}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(visitLogDashboardControllerProvider.notifier).refresh(),
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
              : dashboard.employees
                  .where((employee) =>
                      employee.displayName.toLowerCase().contains(query) ||
                      employee.areaName.toLowerCase().contains(query))
                  .toList();

          final sorted = List.of(employees)
            ..sort((a, b) {
              final aLast = dashboard.logsByEmployee[a.uid]?.firstOrNull?.createdAt;
              final bLast = dashboard.logsByEmployee[b.uid]?.firstOrNull?.createdAt;
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
                        onRefresh: () => ref.read(visitLogDashboardControllerProvider.notifier).refresh(),
                        child: ListView.builder(
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final employee = sorted[index];
                            final logs = dashboard.logsByEmployee[employee.uid] ?? const [];
                            final color = AccentPalette.forLabel(employee.displayName);
                            final name = employee.displayName;
                            final last = logs.firstOrNull;
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
                                        text: '${logs.length} visit${logs.length == 1 ? '' : 's'} logged',
                                        style: TextStyle(color: color, fontWeight: FontWeight.w600),
                                      ),
                                      TextSpan(
                                        text: last == null
                                            ? '\nNo visits logged yet'
                                            : '\nLast: ${last.doctorName} • ${formatDateTime(last.createdAt)}',
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
