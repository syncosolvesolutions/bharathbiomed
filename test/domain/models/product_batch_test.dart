import 'package:bharathbiomedpharma/core/utils/date_of_birth.dart';
import 'package:bharathbiomedpharma/domain/models/product_batch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductBatch.fromJson/toJson', () {
    test('round-trips every field', () {
      final batch = ProductBatch.fromJson('b1', 'p1', {
        'batchNumber': 'BN-001',
        'expiryDate': '2027-01-01',
        'quantity': 50,
      });

      expect(batch.id, 'b1');
      expect(batch.productId, 'p1');
      expect(batch.batchNumber, 'BN-001');
      expect(batch.expiryDate, '2027-01-01');
      expect(batch.quantity, 50);

      final json = batch.toJson();
      expect(json['batchNumber'], 'BN-001');
      expect(json['expiryDate'], '2027-01-01');
      expect(json['quantity'], 50);
    });

    test('defaults safely for a legacy/malformed doc missing fields', () {
      final batch = ProductBatch.fromJson('b1', 'p1', {});
      expect(batch.batchNumber, '');
      expect(batch.expiryDate, '');
      expect(batch.quantity, 0);
    });
  });

  group('isExpired', () {
    test('is true for a past expiry date', () {
      final past = isoFromDate(DateTime.now().subtract(const Duration(days: 1)));
      final batch = ProductBatch(id: 'b1', productId: 'p1', batchNumber: 'BN', expiryDate: past, quantity: 1);
      expect(batch.isExpired, isTrue);
    });

    test('is false for a future expiry date', () {
      final future = isoFromDate(DateTime.now().add(const Duration(days: 30)));
      final batch = ProductBatch(id: 'b1', productId: 'p1', batchNumber: 'BN', expiryDate: future, quantity: 1);
      expect(batch.isExpired, isFalse);
    });

    test('is false for an unparsable expiry date rather than throwing', () {
      const batch = ProductBatch(id: 'b1', productId: 'p1', batchNumber: 'BN', expiryDate: '', quantity: 1);
      expect(batch.isExpired, isFalse);
    });
  });
}
