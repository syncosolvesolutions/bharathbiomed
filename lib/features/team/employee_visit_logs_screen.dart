import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/employee.dart';
import '../admin/usage_format.dart';
import 'visit_log_dashboard_controller.dart';

/// Every recorded doctor visit for one employee, most recent first. Mirrors
/// `EmployeeSessionsScreen`.
class EmployeeVisitLogsScreen extends ConsumerWidget {
  const EmployeeVisitLogsScreen({super.key, required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(visitLogDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${employee.displayName} — Visit Logs')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load visit logs: ${UserFacingError.describe(error)}')),
        data: (dashboard) {
          final logs = dashboard.logsByEmployee[employee.uid] ?? const [];
          if (logs.isEmpty) {
            return const Center(child: Text('No visits logged yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: log.visited ? const Color(0x1A2E7D32) : const Color(0x1AEF6C00),
                  foregroundColor: log.visited ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                  child: Icon(log.visited ? Icons.check : Icons.close, size: 20),
                ),
                title: Text(log.doctorName),
                subtitle: Text(
                  '${log.visitDate} • logged ${formatDateTime(log.createdAt)}'
                  '${log.feedback.isEmpty ? '' : '\n${log.feedback}'}'
                  '${log.latitude != null && log.longitude != null ? '\n${log.latitude!.toStringAsFixed(5)}, ${log.longitude!.toStringAsFixed(5)}' : ''}',
                ),
                isThreeLine: log.feedback.isNotEmpty,
              );
            },
          );
        },
      ),
    );
  }
}
