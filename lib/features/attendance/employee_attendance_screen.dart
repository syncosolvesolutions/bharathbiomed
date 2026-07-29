import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/employee.dart';
import 'attendance_dashboard_controller.dart';

/// Every recorded attendance day for one employee, most recent first.
/// Mirrors [EmployeeVisitLogsScreen].
class EmployeeAttendanceScreen extends ConsumerWidget {
  const EmployeeAttendanceScreen({super.key, required this.employee});

  final Employee employee;

  static String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(attendanceDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${employee.displayName} — Attendance')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load attendance: ${UserFacingError.describe(error)}')),
        data: (dashboard) {
          final days = dashboard.daysByEmployee[employee.uid] ?? const [];
          if (days.isEmpty) {
            return const Center(child: Text('No attendance recorded yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(day.date),
                subtitle: Text('In: ${_formatTime(day.firstCheckIn)}  •  Out: ${_formatTime(day.lastCheckOut)}'
                    '\n${day.sessionCount} session${day.sessionCount == 1 ? '' : 's'}'
                    '${day.hasLocation ? ' • location recorded' : ''}'),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
