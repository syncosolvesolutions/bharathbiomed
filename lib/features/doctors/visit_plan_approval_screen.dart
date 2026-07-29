import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/permission.dart';
import '../team/team_access.dart';
import 'visit_plan_approval_controller.dart';

/// Team beat/route (weekly visit) plan workflow: plans submitted for
/// approval, scoped to the signed-in user's reporting-chain downline (or
/// everyone, for a view_global_data holder). Mirrors
/// [ExpenseClaimApprovalScreen] — approve/reject only, no further
/// fulfillment step.
class VisitPlanApprovalScreen extends ConsumerWidget {
  const VisitPlanApprovalScreen({super.key});

  Future<void> _reject(BuildContext context, WidgetRef ref, String mrUid, String mrName) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Reject $mrName's visit plan?"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason (optional, shown to the MR)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(visitPlanApprovalControllerProvider.notifier).reject(mrUid, reason: controller.text.trim()),
      successMessage: 'Visit plan rejected.',
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action,
      {required String successMessage}) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error, stackTrace) {
      AppLogger.error('VisitPlanApproval', 'action failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(visitPlanApprovalControllerProvider);
    final canApprove = ref.watch(hasPermissionProvider(Permission.approveRequests));

    return Scaffold(
      appBar: AppBar(title: const Text('Visit Plan Approvals')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(visitPlanApprovalControllerProvider.notifier).refresh(),
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load plans: ${UserFacingError.describe(error)}')),
          data: (data) {
            if (data.plans.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nothing needs attention right now.')),
                ],
              );
            }
            final employeesByUid = {for (final e in data.employees) e.uid: e};
            return ListView.builder(
              itemCount: data.plans.length,
              itemBuilder: (context, index) {
                final plan = data.plans[index];
                final Employee? mr = employeesByUid[plan.mrUid];
                final mrName = mr?.displayName ?? plan.mrUid;
                final plannedCount = plan.doctorIdsByWeekday.values.fold<int>(0, (sum, list) => sum + list.length);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mrName, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('$plannedCount planned visit${plannedCount == 1 ? '' : 's'} across the week'),
                        const SizedBox(height: 8),
                        if (canApprove)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _reject(context, ref, plan.mrUid, mrName),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _run(
                                  context,
                                  ref,
                                  () => ref.read(visitPlanApprovalControllerProvider.notifier).approve(plan.mrUid),
                                  successMessage: 'Visit plan approved.',
                                ),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
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
