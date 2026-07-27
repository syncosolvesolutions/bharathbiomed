import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/theme/app_theme.dart';
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(usageDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Usage Dashboard')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Failed to load usage data: ${UserFacingError.describe(error)}'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(usageDashboardControllerProvider.notifier).refresh(),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search employees',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: summaries.isEmpty
                    ? const Center(child: Text('No employees match this search.'))
                    : RefreshIndicator(
                        onRefresh: () => ref.read(usageDashboardControllerProvider.notifier).refresh(),
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
                                onTap: () => context.push('/admin/dashboard/sessions', extra: summary.employee),
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
