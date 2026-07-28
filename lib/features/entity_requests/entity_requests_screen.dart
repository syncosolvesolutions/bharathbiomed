import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../domain/models/entity_change_request.dart';
import 'entity_requests_controller.dart';

/// Pending agency/pharmacy create requests, for an Office Admin to review —
/// mirrors [DoctorRequestsScreen], generalized over [EntityType].
class EntityRequestsScreen extends ConsumerWidget {
  const EntityRequestsScreen({super.key});

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    EntityChangeRequest request, {
    required bool approve,
  }) async {
    String? reviewNote;
    if (!approve) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reject request for ${request.entityName}?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Reason (optional, shown to the requester)'),
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
      await ref
          .read(entityRequestsControllerProvider.notifier)
          .review(request.id, approve: approve, reviewNote: reviewNote);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Approved.' : 'Rejected.')));
    } catch (error, stackTrace) {
      AppLogger.error('EntityRequests', 'review failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to review request: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(entityRequestsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Agency / Pharmacy Requests')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(entityRequestsControllerProvider.future),
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
                final typeLabel = request.entityType == EntityType.agency ? 'Agency' : 'Pharmacy';
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New $typeLabel: ${request.entityName}', style: Theme.of(context).textTheme.titleMedium),
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
