import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/order.dart';
import '../auth/auth_controller.dart';
import '../team/team_access.dart';

/// Orders still needing some team-side action — pending (needs approve/
/// reject), approved (needs dispatch), or dispatched (needs an invoice) —
/// everyone's for a [hasGlobalVisibilityProvider] holder, just the signed-in
/// user's own reporting-chain downline otherwise (see
/// [resolveVisibleEmployees]). Rejected/invoiced orders are terminal and
/// excluded — nothing left to do with them here. Mirrors
/// [UsageDashboardController]'s scoping; fetches unfiltered-by-status and
/// filters client-side since Firestore only allows one `whereIn`/equality
/// filter per query and the uid-scoping already uses it.
final orderApprovalControllerProvider =
    AsyncNotifierProvider<OrderApprovalController, List<Order>>(OrderApprovalController.new);

class OrderApprovalController extends AsyncNotifier<List<Order>> {
  static const _actionable = {OrderStatus.pending, OrderStatus.approved, OrderStatus.dispatched};

  @override
  Future<List<Order>> build() async {
    debugPrint('OrderApprovalController.build: resolving visible employees');
    final orders = ref.read(hasGlobalVisibilityProvider)
        ? await ref.read(orderRepositoryProvider).fetchAll()
        : await ref
            .read(orderRepositoryProvider)
            .fetchForEmployees((await resolveVisibleEmployees(ref)).map((e) => e.uid).toList());
    return orders.where((order) => _actionable.contains(order.status)).toList();
  }

  Future<void> refresh() async {
    debugPrint('OrderApprovalController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }

  /// `approve_orders`-gated in firestore.rules.
  Future<void> approve(String orderId) async {
    debugPrint('OrderApprovalController.approve: orderId=$orderId');
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    await ref.read(orderRepositoryProvider).approve(orderId, approvedByUid: uid);
    await refresh();
  }

  /// `approve_orders`-gated in firestore.rules.
  Future<void> reject(String orderId, {String? reason}) async {
    debugPrint('OrderApprovalController.reject: orderId=$orderId');
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    await ref.read(orderRepositoryProvider).reject(orderId, approvedByUid: uid, reason: reason);
    await refresh();
  }

  /// `dispatch_orders`-gated Cloud Function.
  Future<void> dispatch(String orderId) async {
    debugPrint('OrderApprovalController.dispatch: orderId=$orderId');
    await ref.read(orderRepositoryProvider).dispatch(orderId);
    await refresh();
  }

  /// `manage_invoices`-gated Cloud Function.
  Future<void> generateInvoice(String orderId) async {
    debugPrint('OrderApprovalController.generateInvoice: orderId=$orderId');
    await ref.read(invoiceRepositoryProvider).generate(orderId);
    await refresh();
  }
}
