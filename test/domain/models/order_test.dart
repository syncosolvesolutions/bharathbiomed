import 'package:bharathbiomedpharma/domain/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Order.fromJson/toJson', () {
    test('round-trips a dispatched order', () {
      final order = Order.fromJson('o1', {
        'agencyId': 'a1',
        'agencyName': 'MedSupply Co',
        'createdByUid': 'mr1',
        'createdByName': 'Rajesh',
        'items': [
          {'productId': 'p1', 'productName': 'Paracetamol', 'quantity': 10, 'unitPrice': 5},
        ],
        'status': 'dispatched',
        'dispatchedByUid': 'mgr1',
      });

      expect(order.status, OrderStatus.dispatched);
      expect(order.totalValue, 50);
      expect(order.dispatchedByUid, 'mgr1');

      final json = order.toCreateJson();
      expect(json['status'], 'pending');
      expect(json['agencyId'], 'a1');
      expect(json['totalValue'], 50);
    });

    test('parses a delivered order', () {
      final order = Order.fromJson('o1', {
        'agencyId': 'a1',
        'agencyName': 'MedSupply Co',
        'createdByUid': 'mr1',
        'createdByName': 'Rajesh',
        'items': [],
        'status': 'delivered',
      });

      expect(order.status, OrderStatus.delivered);
      expect(orderStatusToJson(order.status), 'delivered');
    });

    test('defaults to pending for a legacy/malformed status', () {
      final order = Order.fromJson('o1', {
        'agencyId': 'a1',
        'agencyName': 'MedSupply Co',
        'createdByUid': 'mr1',
        'createdByName': 'Rajesh',
        'items': [],
        'status': 'invoiced',
      });

      expect(order.status, OrderStatus.pending);
    });
  });
}
