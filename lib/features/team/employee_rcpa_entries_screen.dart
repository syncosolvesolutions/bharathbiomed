import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/employee.dart';
import '../admin/usage_format.dart';
import 'rcpa_dashboard_controller.dart';

/// Every logged RCPA entry for one employee, most recent first. Mirrors
/// `EmployeeVisitLogsScreen`.
class EmployeeRcpaEntriesScreen extends ConsumerWidget {
  const EmployeeRcpaEntriesScreen({super.key, required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(rcpaDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${employee.displayName} — RCPA Entries')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load entries: ${UserFacingError.describe(error)}')),
        data: (dashboard) {
          final entries = dashboard.entriesByEmployee[employee.uid] ?? const [];
          if (entries.isEmpty) {
            return const Center(child: Text('No entries logged yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                title: Text(entry.pharmacyName),
                subtitle: Text(
                  '${entry.auditDate} • logged ${formatDateTime(entry.createdAt)}\n'
                  '${entry.totalOwnBrandCount} own-brand, ${entry.totalCompetitorCount} competitor'
                  '${entry.notes.isEmpty ? '' : '\n${entry.notes}'}',
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
