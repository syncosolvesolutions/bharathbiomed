import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/leave_request.dart';
import 'my_leave_requests_controller.dart';

/// The signed-in MR's own filed leave requests and their live status.
/// Mirrors [MyExpenseClaimsScreen].
class MyLeaveRequestsScreen extends ConsumerWidget {
  const MyLeaveRequestsScreen({super.key});

  Color _statusColor(LeaveRequestStatus status) => switch (status) {
        LeaveRequestStatus.pending => Colors.orange,
        LeaveRequestStatus.approved => Colors.green,
        LeaveRequestStatus.rejected => Colors.red,
      };

  String _statusLabel(LeaveRequestStatus status) => switch (status) {
        LeaveRequestStatus.pending => 'Pending approval',
        LeaveRequestStatus.approved => 'Approved',
        LeaveRequestStatus.rejected => 'Rejected',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myLeaveRequestsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Leave Requests')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myLeaveRequestsControllerProvider.notifier).refresh(),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load requests: ${UserFacingError.describe(error)}')),
          data: (requests) {
            if (requests.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No leave requests yet.\nTap "Request Leave" below.', textAlign: TextAlign.center)),
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
                  child: ListTile(
                    title: Text(request.leaveType.label),
                    subtitle: Text(
                        '${sameDay ? request.startDate : '${request.startDate} — ${request.endDate}'}'
                        '${request.reason.isNotEmpty ? '\n${request.reason}' : ''}'
                        '${request.rejectedReason?.isNotEmpty ?? false ? '\nReason: ${request.rejectedReason}' : ''}'),
                    isThreeLine: request.reason.isNotEmpty || (request.rejectedReason?.isNotEmpty ?? false),
                    trailing: Chip(
                      label: Text(_statusLabel(request.status),
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: _statusColor(request.status),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/leave/add'),
        icon: const Icon(Icons.add),
        label: const Text('Request Leave'),
      ),
    );
  }
}
