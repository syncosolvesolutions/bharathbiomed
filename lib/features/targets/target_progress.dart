import '../../domain/models/order.dart';
import '../../domain/models/sales_target.dart';

/// A target (if one's been set for this period) plus the real achievement
/// rolled up from that employee's own orders — never a manually-entered
/// number. Only orders that are at least [OrderStatus.approved] count
/// (pending isn't a confirmed sale yet; rejected never was one).
class TargetProgress {
  const TargetProgress({required this.period, this.target, required this.achievement});

  final String period;
  final SalesTarget? target;
  final double achievement;

  double get fraction {
    final targetValue = target?.targetValue ?? 0;
    if (targetValue <= 0) return 0;
    return (achievement / targetValue).clamp(0, 1);
  }
}

const _achievedStatuses = {OrderStatus.approved, OrderStatus.dispatched, OrderStatus.delivered};

/// Sums [orders] whose `createdAt` falls in [period] and whose status counts
/// as an actual confirmed sale — shared by [MyTargetController] and
/// [TeamTargetsController] so both compute achievement identically.
double achievementForPeriod(List<Order> orders, String period) {
  var sum = 0.0;
  for (final order in orders) {
    if (order.createdAt == null) continue;
    if (!_achievedStatuses.contains(order.status)) continue;
    final orderPeriod = '${order.createdAt!.year}-${order.createdAt!.month.toString().padLeft(2, '0')}';
    if (orderPeriod == period) sum += order.totalValue;
  }
  return sum;
}
