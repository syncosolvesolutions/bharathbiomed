import 'package:bharathbiomedpharma/domain/models/order.dart';
import 'package:bharathbiomedpharma/domain/models/sales_target.dart';
import 'package:bharathbiomedpharma/features/targets/target_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Order buildOrder({required OrderStatus status, required DateTime createdAt, required double unitPrice}) {
    return Order(
      id: 'o1',
      agencyId: 'a1',
      agencyName: 'Agency',
      createdByUid: 'mr1',
      createdByName: 'Rajesh',
      items: [OrderItem(productId: 'p1', productName: 'Paracetamol', quantity: 1, unitPrice: unitPrice)],
      status: status,
      createdAt: createdAt,
    );
  }

  group('achievementForPeriod', () {
    test('sums only orders in the given period', () {
      final orders = [
        buildOrder(status: OrderStatus.approved, createdAt: DateTime(2026, 7, 5), unitPrice: 100),
        buildOrder(status: OrderStatus.approved, createdAt: DateTime(2026, 8, 5), unitPrice: 999),
      ];
      expect(achievementForPeriod(orders, '2026-07'), 100);
    });

    test('excludes pending and rejected orders', () {
      final orders = [
        buildOrder(status: OrderStatus.pending, createdAt: DateTime(2026, 7, 5), unitPrice: 100),
        buildOrder(status: OrderStatus.rejected, createdAt: DateTime(2026, 7, 6), unitPrice: 200),
      ];
      expect(achievementForPeriod(orders, '2026-07'), 0);
    });

    test('includes approved, dispatched, and delivered orders', () {
      final orders = [
        buildOrder(status: OrderStatus.approved, createdAt: DateTime(2026, 7, 1), unitPrice: 10),
        buildOrder(status: OrderStatus.dispatched, createdAt: DateTime(2026, 7, 2), unitPrice: 20),
        buildOrder(status: OrderStatus.delivered, createdAt: DateTime(2026, 7, 3), unitPrice: 30),
      ];
      expect(achievementForPeriod(orders, '2026-07'), 60);
    });
  });

  group('TargetProgress.fraction', () {
    test('is 0 when there is no target', () {
      const progress = TargetProgress(period: '2026-07', target: null, achievement: 500);
      expect(progress.fraction, 0);
    });

    test('clamps to 1 when achievement exceeds the target', () {
      const progress = TargetProgress(
        period: '2026-07',
        target: SalesTarget(id: 't1', employeeUid: 'mr1', period: '2026-07', targetValue: 500, createdByUid: 'rm1'),
        achievement: 1000,
      );
      expect(progress.fraction, 1);
    });
  });
}
