import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/theme/accent_palette.dart';
import '../../core/utils/report_export_service.dart';
import '../../core/widgets/export_menu_button.dart';
import '../team/team_access.dart';
import 'team_targets_controller.dart';

/// Current-month target vs. achievement for the signed-in user's own
/// reporting-chain downline (or everyone, for a global-visibility holder) —
/// see [TeamTargetsController]. A "Set Target" action per row is only shown
/// to a [canManageTargetsProvider] holder.
class TeamTargetsScreen extends ConsumerWidget {
  const TeamTargetsScreen({super.key});

  List<List<String>> _rows(List<EmployeeTargetProgress> entries) => entries
      .map((entry) => [
            entry.employee.displayName,
            entry.progress.target?.targetValue.toStringAsFixed(2) ?? 'Not set',
            entry.progress.achievement.toStringAsFixed(2),
            '${(entry.progress.fraction * 100).round()}%',
          ])
      .toList();

  Future<void> _exportCsv(WidgetRef ref, List<EmployeeTargetProgress> entries) {
    return ref.read(reportExportServiceProvider).exportCsv(
          filename: 'team_targets.csv',
          headers: const ['Employee', 'Target', 'Achievement', 'Progress'],
          rows: _rows(entries),
        );
  }

  Future<void> _exportPdf(WidgetRef ref, List<EmployeeTargetProgress> entries) {
    return ref.read(reportExportServiceProvider).exportSimpleTablePdf(
          filename: 'team_targets.pdf',
          title: 'Team Targets — Current Month',
          headers: const ['Employee', 'Target', 'Achievement', 'Progress'],
          rows: _rows(entries),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(teamTargetsControllerProvider);
    final canManage = ref.watch(canManageTargetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Targets'),
        actions: [
          if (progressAsync.value != null)
            ExportMenuButton(
              onExportCsv: () => _exportCsv(ref, progressAsync.value!),
              onExportPdf: () => _exportPdf(ref, progressAsync.value!),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(teamTargetsControllerProvider.notifier).refresh(),
        child: progressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load targets: ${UserFacingError.describe(error)}')),
          data: (entries) {
            if (entries.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No team members yet.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final progress = entry.progress;
                final color = AccentPalette.forLabel(entry.employee.displayName);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              foregroundColor: color,
                              child: Text(entry.employee.displayName.isNotEmpty
                                  ? entry.employee.displayName[0].toUpperCase()
                                  : '?'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(entry.employee.displayName)),
                            if (canManage)
                              TextButton(
                                onPressed: () => context.push('/targets/set', extra: entry.employee),
                                child: const Text('Set Target'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (progress.target == null)
                          const Text('No target set this month.')
                        else ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: progress.fraction, minHeight: 8),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${progress.achievement.toStringAsFixed(2)} / ${progress.target!.targetValue.toStringAsFixed(2)}'
                            ' (${(progress.fraction * 100).round()}%)',
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
