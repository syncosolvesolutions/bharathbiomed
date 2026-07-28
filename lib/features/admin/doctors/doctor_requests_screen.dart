import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_logger.dart';
import '../../../core/error/user_facing_error.dart';
import '../../../domain/models/doctor_change_request.dart';
import 'doctor_requests_controller.dart';

/// Requirement 5: "admin should see list of requests for doctor addition,
/// updation". Each request shows what the MR proposed; approving applies it
/// to `Doctors` immediately (see `reviewDoctorChangeRequest` Cloud
/// Function), rejecting just records the reviewer's note and notifies the MR.
class DoctorRequestsScreen extends ConsumerWidget {
  const DoctorRequestsScreen({super.key});

  Future<void> _review(BuildContext context, WidgetRef ref, DoctorChangeRequest request, {required bool approve}) async {
    String? reviewNote;
    if (!approve) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reject request for ${request.doctorName}?'),
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
      if (confirmed != true) return;
      reviewNote = controller.text.trim();
    }

    try {
      await ref.read(doctorRequestsControllerProvider.notifier).review(request.id, approve: approve, reviewNote: reviewNote);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(approve ? 'Approved.' : 'Rejected.')));
    } catch (error, stackTrace) {
      AppLogger.error('DoctorRequests', 'review failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to review request: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(doctorRequestsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Requests')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(doctorRequestsControllerProvider.future),
        child: requestsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load requests: ${UserFacingError.describe(error)}')),
          data: (requests) {
            if (requests.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No pending requests.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final isUpdate = request.type == DoctorChangeType.update;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isUpdate ? 'Edit' : 'New doctor'}: ${request.doctorName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(request.hospitalName),
                        const SizedBox(height: 4),
                        Text('Requested by ${request.requestedByName}', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _review(context, ref, request, approve: false),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _review(context, ref, request, approve: true),
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
