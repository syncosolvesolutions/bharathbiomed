import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/compliance_log.dart';
import 'my_compliance_logs_controller.dart';

/// The signed-in MR's own logged compliance records. Mirrors
/// [RcpaListScreen].
class MyComplianceLogsScreen extends ConsumerWidget {
  const MyComplianceLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(myComplianceLogsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compliance Log')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myComplianceLogsControllerProvider.notifier).refresh(),
        child: logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load logs: ${UserFacingError.describe(error)}')),
          data: (logs) {
            if (logs.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No compliance entries yet.\nTap "Log Entry" below.', textAlign: TextAlign.center)),
                ],
              );
            }
            return ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text('${log.doctorName} — ${log.category.label}'),
                    subtitle: Text('${log.logDate} • value ${log.value.toStringAsFixed(2)}'
                        '${log.description.isEmpty ? '' : '\n${log.description}'}'),
                    isThreeLine: log.description.isNotEmpty,
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/compliance/add'),
        icon: const Icon(Icons.gavel_outlined),
        label: const Text('Log Entry'),
      ),
    );
  }
}
