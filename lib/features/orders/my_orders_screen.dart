import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../domain/models/order.dart';
import 'order_controller.dart';

/// The signed-in MR's own placed orders and their live status. See
/// [MyOrdersController] for why not-yet-uploaded (still-local) orders don't
/// show up here — the sync banner/progress overlay already covers "you have
/// something queued."
class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  Color _statusColor(OrderStatus status) => switch (status) {
        OrderStatus.pending => Colors.orange,
        OrderStatus.approved => Colors.blue,
        OrderStatus.rejected => Colors.red,
        OrderStatus.dispatched => Colors.teal,
        OrderStatus.delivered => Colors.green,
      };

  String _statusLabel(OrderStatus status) => switch (status) {
        OrderStatus.pending => 'Pending approval',
        OrderStatus.approved => 'Approved',
        OrderStatus.rejected => 'Rejected',
        OrderStatus.dispatched => 'Dispatched',
        OrderStatus.delivered => 'Delivered',
      };

  Future<void> _markDelivered(BuildContext context, WidgetRef ref, Order order) async {
    try {
      await ref.read(myOrdersControllerProvider.notifier).markDelivered(order.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as delivered.')));
    } catch (error, stackTrace) {
      AppLogger.error('MyOrders', 'markDelivered failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myOrdersControllerProvider.notifier).refresh(),
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load orders: ${UserFacingError.describe(error)}')),
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No orders yet.\nTap "Place Order" below.', textAlign: TextAlign.center)),
                ],
              );
            }
            return ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(order.agencyName),
                    subtitle: Text('${order.items.length} product${order.items.length == 1 ? '' : 's'} '
                        '• ${order.totalValue.toStringAsFixed(2)}'
                        '${order.rejectedReason?.isNotEmpty ?? false ? '\n${order.rejectedReason}' : ''}'),
                    isThreeLine: order.rejectedReason?.isNotEmpty ?? false,
                    trailing: order.status == OrderStatus.dispatched
                        ? ElevatedButton(
                            onPressed: () => _markDelivered(context, ref, order),
                            child: const Text('Mark Delivered'),
                          )
                        : Chip(
                            label:
                                Text(_statusLabel(order.status), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: _statusColor(order.status),
                          ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders/add'),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Place Order'),
      ),
    );
  }
}
