import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/employee.dart';
import 'usage_dashboard_controller.dart';
import 'usage_format.dart';

/// Every recorded session for one employee, most recent first.
class EmployeeSessionsScreen extends ConsumerWidget {
  const EmployeeSessionsScreen({super.key, required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(usageDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${employee.displayName} — Sessions')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load sessions: ${UserFacingError.describe(error)}')),
        data: (dashboard) {
          final sessions = dashboard.sessionsByEmployee[employee.uid] ?? const [];
          if (sessions.isEmpty) {
            return const Center(child: Text('No recorded sessions yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A3470B2),
                  foregroundColor: Color(0xFF3470B2),
                  child: Icon(Icons.schedule, size: 20),
                ),
                title: Text(formatDateTime(session.openedAt)),
                subtitle: Text(
                  '${session.duration == null ? 'Duration unavailable' : formatDuration(session.duration!)} • '
                  '${session.hasLocation ? '${session.latitude!.toStringAsFixed(5)}, ${session.longitude!.toStringAsFixed(5)}' : 'Location unavailable'}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
