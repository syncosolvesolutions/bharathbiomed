import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../domain/models/expense_claim.dart';
import '../../domain/models/permission.dart';
import '../team/team_access.dart';
import 'expense_claim_approval_controller.dart';

/// Team expense-claim workflow: pending claims needing approve/reject,
/// scoped to the signed-in user's reporting-chain downline (or everyone,
/// for a view_global_data holder). Mirrors [OrderApprovalScreen], minus the
/// dispatch step a claim doesn't have.
class ExpenseClaimApprovalScreen extends ConsumerWidget {
  const ExpenseClaimApprovalScreen({super.key});

  Future<void> _reject(BuildContext context, WidgetRef ref, String claimId, String mrName) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject claim from $mrName?'),
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
      () => ref.read(expenseClaimApprovalControllerProvider.notifier).reject(claimId, reason: controller.text.trim()),
      successMessage: 'Claim rejected.',
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action,
      {required String successMessage}) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error, stackTrace) {
      AppLogger.error('ExpenseClaimApproval', 'action failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(expenseClaimApprovalControllerProvider);
    final canApprove = ref.watch(hasPermissionProvider(Permission.approveExpenses));

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Claim Workflow')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(expenseClaimApprovalControllerProvider.notifier).refresh(),
        child: claimsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load claims: ${UserFacingError.describe(error)}')),
          data: (claims) {
            if (claims.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nothing needs attention right now.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: claims.length,
              itemBuilder: (context, index) {
                final claim = claims[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${claim.mrName} — ${claim.category.label}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('${claim.claimDate} • ${claim.amount.toStringAsFixed(2)}'
                            '${claim.description.isNotEmpty ? '\n${claim.description}' : ''}'),
                        const SizedBox(height: 8),
                        if (canApprove)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _reject(context, ref, claim.id, claim.mrName),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _run(
                                  context,
                                  ref,
                                  () => ref.read(expenseClaimApprovalControllerProvider.notifier).approve(claim.id),
                                  successMessage: 'Claim approved.',
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
