import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../domain/models/order.dart';
import '../../domain/models/permission.dart';
import '../team/team_access.dart';
import 'order_approval_controller.dart';

/// Team order workflow: pending orders needing approve/reject, approved
/// orders needing dispatch — scoped to the signed-in user's reporting-chain
/// downline (or everyone, for a view_global_data holder). Each action button
/// only shows for whoever actually holds that permission (see [Permission])
/// — someone with `approve_orders` but not `dispatch_orders` sees Approve/
/// Reject but no Dispatch button, for example. Once dispatched, an order
/// waits on the MR's own "Mark Delivered" (see `MyOrdersScreen`), not a team
/// action — invoicing/payment happen entirely offline.
class OrderApprovalScreen extends ConsumerWidget {
  const OrderApprovalScreen({super.key});

  Future<void> _reject(BuildContext context, WidgetRef ref, Order order) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject order from ${order.createdByName}?'),
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
      () => ref.read(orderApprovalControllerProvider.notifier).reject(order.id, reason: controller.text.trim()),
      successMessage: 'Order rejected.',
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action,
      {required String successMessage}) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error, stackTrace) {
      AppLogger.error('OrderApproval', 'action failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderApprovalControllerProvider);
    final canApprove = ref.watch(hasPermissionProvider(Permission.approveOrders));
    final canDispatch = ref.watch(hasPermissionProvider(Permission.dispatchOrders));

    return Scaffold(
      appBar: AppBar(title: const Text('Order Workflow')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(orderApprovalControllerProvider.notifier).refresh(),
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load orders: ${UserFacingError.describe(error)}')),
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nothing needs attention right now.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${order.agencyName} — ${order.createdByName}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('${order.items.length} product${order.items.length == 1 ? '' : 's'} '
                            '• ${order.totalValue.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (order.status == OrderStatus.pending && canApprove) ...[
                              TextButton(
                                onPressed: () => _reject(context, ref, order),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _run(
                                  context,
                                  ref,
                                  () => ref.read(orderApprovalControllerProvider.notifier).approve(order.id),
                                  successMessage: 'Order approved.',
                                ),
                                child: const Text('Approve'),
                              ),
                            ],
                            if (order.status == OrderStatus.approved && canDispatch)
                              ElevatedButton(
                                onPressed: () => _run(
                                  context,
                                  ref,
                                  () => ref.read(orderApprovalControllerProvider.notifier).dispatch(order.id),
                                  successMessage: 'Order dispatched — stock updated.',
                                ),
                                child: const Text('Dispatch'),
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
