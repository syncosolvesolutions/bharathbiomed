import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/invoice.dart';
import '../../domain/models/payment.dart';

/// `Invoices`: read-only from the client — every invoice is created by the
/// `generateInvoice` Cloud Function (race-safe sequential numbering via a
/// counter doc), never written directly. `Payments` (a subcollection-shaped
/// concern but modeled as its own top-level collection, filtered by
/// `invoiceId`) is the same: only `recordPayment` (Cloud Function) writes.
class InvoiceRemoteDataSource {
  InvoiceRemoteDataSource({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<List<Invoice>> fetchAll() async {
    debugPrint('InvoiceRemoteDataSource.fetchAll: fetching Invoices collection');
    final snapshot = await _firestore.collection('Invoices').orderBy('issuedAt', descending: true).get();
    debugPrint('InvoiceRemoteDataSource.fetchAll: fetched ${snapshot.docs.length} invoices');
    return snapshot.docs.map((doc) => Invoice.fromJson(doc.id, doc.data())).toList();
  }

  /// `manage_invoices`-gated Cloud Function: verifies the order is
  /// `dispatched`, assigns the next sequential invoice number, writes the
  /// `Invoices` doc, and marks the order `invoiced`.
  Future<void> generate(String orderId) async {
    debugPrint('InvoiceRemoteDataSource.generate: orderId=$orderId');
    await _functions.httpsCallable('generateInvoice').call({'orderId': orderId});
  }

  Future<List<Payment>> fetchPayments(String invoiceId) async {
    debugPrint('InvoiceRemoteDataSource.fetchPayments: invoiceId=$invoiceId');
    final snapshot = await _firestore.collection('Payments').where('invoiceId', isEqualTo: invoiceId).get();
    final payments = snapshot.docs.map((doc) => Payment.fromJson(doc.id, doc.data())).toList()
      ..sort((a, b) => (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)));
    return payments;
  }

  /// `manage_invoices`-gated Cloud Function: records the payment and
  /// updates the invoice's `amountPaid`/`paymentStatus` atomically.
  Future<void> recordPayment(String invoiceId, {required double amount, String? notes}) async {
    debugPrint('InvoiceRemoteDataSource.recordPayment: invoiceId=$invoiceId amount=$amount');
    await _functions.httpsCallable('recordPayment').call({
      'invoiceId': invoiceId,
      'amount': amount,
      'notes': notes,
    });
  }
}
