import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/date_of_birth.dart';

/// A batch/lot of stock for one [Product] (`Products/{productId}/Batches/
/// {batchId}`), with its own expiry date — pharma stock is bought and sold
/// in dated lots, unlike this app's original flat `Product.stockQuantity`
/// counter (still the authoritative total the ordering/dispatch flow
/// checks against; batches are an additive tracking layer on top, not a
/// replacement — see `ManageInventoryScreen`'s doc comment for why, and
/// `functions/src/index.ts`'s `dispatchOrder` for how the two stay in
/// sync).
class ProductBatch extends Equatable {
  final String id;
  final String productId;
  final String batchNumber;

  /// Plain `"YYYY-MM-DD"`, same rationale as elsewhere in this app — this
  /// is a calendar day, not a point in time. Lexicographically comparable
  /// (zero-padded ISO), which is why range queries like
  /// `fetchExpiringWithinDays` can filter on it directly as a string.
  final String expiryDate;
  final int quantity;
  final DateTime? createdAt;

  const ProductBatch({
    required this.id,
    required this.productId,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
    this.createdAt,
  });

  bool get isExpired {
    final expiry = dateFromIso(expiryDate);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  factory ProductBatch.fromJson(String id, String productId, Map<String, dynamic> json) {
    debugPrint('ProductBatch.fromJson: parsing batch id=$id productId=$productId');
    return ProductBatch(
      id: id,
      productId: productId,
      batchNumber: json['batchNumber'] as String? ?? '',
      expiryDate: json['expiryDate'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      createdAt: _dateFromAny(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'batchNumber': batchNumber,
        'expiryDate': expiryDate,
        'quantity': quantity,
      };

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
  List<Object?> get props => [id, productId, batchNumber, expiryDate, quantity, createdAt];
}
