import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../domain/models/leave_request.dart';
import '../../domain/models/permission.dart';
import '../team/team_access.dart';
import 'leave_request_approval_controller.dart';

/// Team leave-request workflow: pending requests needing approve/reject,
/// scoped to the signed-in user's reporting-chain downline (or everyone,
/// for a view_global_data holder). Mirrors [ExpenseClaimApprovalScreen].
class LeaveRequestApprovalScreen extends ConsumerWidget {
  const LeaveRequestApprovalScreen({super.key});

  Future<void> _reject(BuildContext context, WidgetRef ref, String requestId, String mrName) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject leave request from $mrName?'),
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
      () => ref.read(leaveRequestApprovalControllerProvider.notifier).reject(requestId, reason: controller.text.trim()),
      successMessage: 'Leave request rejected.',
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action,
      {required String successMessage}) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error, stackTrace) {
      AppLogger.error('LeaveRequestApproval', 'action failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(leaveRequestApprovalControllerProvider);
    final canApprove = ref.watch(hasPermissionProvider(Permission.approveLeave));

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Request Workflow')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(leaveRequestApprovalControllerProvider.notifier).refresh(),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load requests: ${UserFacingError.describe(error)}')),
          data: (requests) {
            if (requests.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nothing needs attention right now.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final sameDay = request.startDate == request.endDate;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${request.mrName} — ${request.leaveType.label}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('${sameDay ? request.startDate : '${request.startDate} — ${request.endDate}'}'
                            '${request.reason.isNotEmpty ? '\n${request.reason}' : ''}'),
                        const SizedBox(height: 8),
                        if (canApprove)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _reject(context, ref, request.id, request.mrName),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _run(
                                  context,
                                  ref,
                                  () => ref.read(leaveRequestApprovalControllerProvider.notifier).approve(request.id),
                                  successMessage: 'Leave request approved.',
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
