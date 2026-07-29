import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/order.dart';
import '../auth/auth_controller.dart';

/// The signed-in MR's own placed orders, live from Firestore (see
/// [OrderRepository.fetchMine]) — connectivity-assumed, same reasoning as
/// [DoctorRequestsController]: an order's live status only matters once it's
/// actually reached the server. Not-yet-uploaded orders (still in the local
/// queue) aren't shown here — see `SyncController`'s pending-upload count for
/// that instead.
final myOrdersControllerProvider = AsyncNotifierProvider<MyOrdersController, List<Order>>(MyOrdersController.new);

class MyOrdersController extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    final uid = ref.read(authControllerProvider).value?.uid;
    debugPrint('MyOrdersController.build: uid=$uid');
    if (uid == null) return [];
    return ref.read(orderRepositoryProvider).fetchMine(uid);
  }

  Future<void> refresh() async {
    debugPrint('MyOrdersController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }

  /// Ownership-scoped in firestore.rules — only this order's own creator may
  /// call it, and only while `dispatched`.
  Future<void> markDelivered(String orderId) async {
    debugPrint('MyOrdersController.markDelivered: orderId=$orderId');
    await ref.read(orderRepositoryProvider).markDelivered(orderId);
    await refresh();
  }
}
