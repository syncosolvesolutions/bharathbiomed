import 'package:bharathbiomedpharma/domain/models/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invoice.fromJson', () {
    test('round-trips tax and payment fields', () {
      final invoice = Invoice.fromJson('i1', {
        'orderId': 'o1',
        'invoiceNumber': 'INV-000001',
        'agencyId': 'a1',
        'agencyName': 'MedSupply Co',
        'items': [],
        'totalValue': 100,
        'taxLabel': 'GST',
        'taxRate': 12,
        'taxAmount': 12,
        'grandTotal': 112,
        'paymentStatus': 'partial',
        'amountPaid': 50,
      });

      expect(invoice.taxLabel, 'GST');
      expect(invoice.taxRate, 12);
      expect(invoice.taxAmount, 12);
      expect(invoice.grandTotal, 112);
      expect(invoice.paymentStatus, PaymentStatus.partial);
      expect(invoice.amountPaid, 50);
      expect(invoice.balanceDue, 62);
    });

    test('falls back to totalValue for grandTotal on a legacy invoice with no tax fields', () {
      final invoice = Invoice.fromJson('i1', {
        'orderId': 'o1',
        'invoiceNumber': 'INV-000001',
        'agencyId': 'a1',
        'agencyName': 'MedSupply Co',
        'items': [],
        'totalValue': 100,
      });

      expect(invoice.grandTotal, 100);
      expect(invoice.paymentStatus, PaymentStatus.unpaid);
    });
  });

  group('isOverdue', () {
    test('is true when unpaid and past the due date', () {
      final invoice = Invoice(
        id: 'i1',
        orderId: 'o1',
        invoiceNumber: 'INV-000001',
        agencyId: 'a1',
        agencyName: 'MedSupply Co',
        items: const [],
        totalValue: 100,
        grandTotal: 100,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(invoice.isOverdue, isTrue);
    });

    test('is false once fully paid, even past the due date', () {
      final invoice = Invoice(
        id: 'i1',
        orderId: 'o1',
        invoiceNumber: 'INV-000001',
        agencyId: 'a1',
        agencyName: 'MedSupply Co',
        items: const [],
        totalValue: 100,
        grandTotal: 100,
        amountPaid: 100,
        paymentStatus: PaymentStatus.paid,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(invoice.isOverdue, isFalse);
    });

    test('is false with no due date set', () {
      const invoice = Invoice(
        id: 'i1',
        orderId: 'o1',
        invoiceNumber: 'INV-000001',
        agencyId: 'a1',
        agencyName: 'MedSupply Co',
        items: [],
        totalValue: 100,
      );
      expect(invoice.isOverdue, isFalse);
    });
  });
}
