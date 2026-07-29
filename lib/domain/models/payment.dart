import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// One payment recorded against an [Invoice] — append-only (a correction
/// is a new negative-amount... no: see `recordPayment`'s doc comment,
/// negative amounts are rejected; a mistaken payment is corrected by
/// whoever manages invoices recording the discrepancy in [notes], not by
/// editing or deleting this record). Written only by the `recordPayment`
/// Cloud Function, which also updates the parent `Invoice.amountPaid`/
/// `paymentStatus` in the same transaction — never written to directly by
/// a client.
class Payment extends Equatable {
  final String id;
  final String invoiceId;
  final double amount;

  /// Not resolved to a display name anywhere in this app — same pattern as
  /// `Order.approvedByUid`/`ExpenseClaim.approvedByUid`, neither of which
  /// is joined against `Employee` for display either.
  final String recordedByUid;
  final String notes;
  final DateTime? paidAt;

  const Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.recordedByUid,
    this.notes = '',
    this.paidAt,
  });

  factory Payment.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('Payment.fromJson: parsing payment id=$id');
    return Payment(
      id: id,
      invoiceId: json['invoiceId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      recordedByUid: json['recordedByUid'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      paidAt: _dateFromAny(json['paidAt']),
    );
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [id, invoiceId, amount, recordedByUid, notes, paidAt];
}
