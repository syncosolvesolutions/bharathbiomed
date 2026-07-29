import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import 'compliance_dashboard_controller.dart';

/// Per-doctor cumulative UCPMP compliance value for the current calendar
/// year, most-valuable first — doctors over
/// `TenantConfig.ucpmpAnnualLimitPerDoctor` are flagged. See
/// [DoctorComplianceSummary]'s doc comment for why this aggregates by
/// doctor rather than by MR.
class ComplianceDashboardScreen extends ConsumerWidget {
  const ComplianceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(complianceDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Compliance Dashboard')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(complianceDashboardControllerProvider.notifier).refresh(),
        child: summariesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load: ${UserFacingError.describe(error)}')),
          data: (summaries) {
            if (summaries.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No compliance entries logged this year.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: summaries.length,
              itemBuilder: (context, index) {
                final summary = summaries[index];
                final color = summary.isOverLimit ? Theme.of(context).colorScheme.error : null;
                return ListTile(
                  leading: Icon(
                    summary.isOverLimit ? Icons.error_outline : Icons.check_circle_outline,
                    color: color ?? Colors.green,
                  ),
                  title: Text(summary.doctorName),
                  subtitle: Text(
                    '${summary.entryCount} entr${summary.entryCount == 1 ? 'y' : 'ies'} • '
                    'value ${summary.totalValue.toStringAsFixed(2)} this year'
                    '${summary.isOverLimit ? ' — over limit' : ''}',
                    style: color != null ? TextStyle(color: color, fontWeight: FontWeight.w600) : null,
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
