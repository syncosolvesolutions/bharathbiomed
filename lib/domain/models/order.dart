import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// One line of an [Order]: how much of one product, at what price.
class OrderItem extends Equatable {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get lineTotal => quantity * unitPrice;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  @override
  List<Object?> get props => [productId, productName, quantity, unitPrice];
}

/// `pending` (awaiting approval) -> `approved`/`rejected` -> (if approved)
/// `dispatched` (stock decremented — see the `dispatchOrder` Cloud
/// Function, set by the office when the product is physically sent) ->
/// `delivered` (a direct firestore.rules-gated write by the order's own
/// creator only — see `markDelivered` — set by the MR once the product is
/// physically received). Invoicing/cheques/payments are handled entirely
/// offline outside the app, so there is no further status after this.
enum OrderStatus { pending, approved, rejected, dispatched, delivered }

OrderStatus orderStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return OrderStatus.approved;
    case 'rejected':
      return OrderStatus.rejected;
    case 'dispatched':
      return OrderStatus.dispatched;
    case 'delivered':
      return OrderStatus.delivered;
    default:
      return OrderStatus.pending;
  }
}

String orderStatusToJson(OrderStatus status) => switch (status) {
      OrderStatus.pending => 'pending',
      OrderStatus.approved => 'approved',
      OrderStatus.rejected => 'rejected',
      OrderStatus.dispatched => 'dispatched',
      OrderStatus.delivered => 'delivered',
    };

/// An MR-placed order against an [Agency] — the full commercial lifecycle:
/// [OrderStatus.pending] (created here) -> approve/reject (a direct
/// firestore.rules-gated write — see `approve_orders`) -> dispatch (Cloud
/// Function, decrements inventory) -> delivered (a direct, ownership-scoped
/// write by the MR who created it). Created offline-first like
/// [DoctorVisitLog] (queued locally, uploaded on the next sync); once
/// uploaded, its live status is only ever read from Firestore directly (see
/// `OrderRepository.fetchMine`), not re-cached locally.
class Order extends Equatable {
  final String id;
  final String agencyId;
  final String agencyName;
  final String createdByUid;
  final String createdByName;
  final List<OrderItem> items;
  final OrderStatus status;
  final String? approvedByUid;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final String? dispatchedByUid;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final DateTime? createdAt;

  const Order({
    required this.id,
    required this.agencyId,
    required this.agencyName,
    required this.createdByUid,
    required this.createdByName,
    required this.items,
    this.status = OrderStatus.pending,
    this.approvedByUid,
    this.approvedAt,
    this.rejectedReason,
    this.dispatchedByUid,
    this.dispatchedAt,
    this.deliveredAt,
    this.createdAt,
  });

  double get totalValue => items.fold(0, (sum, item) => sum + item.lineTotal);

  factory Order.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('Order.fromJson: parsing order id=$id');
    return Order(
      id: id,
      agencyId: json['agencyId'] as String? ?? '',
      agencyName: json['agencyName'] as String? ?? '',
      createdByUid: json['createdByUid'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? '',
      items: (json['items'] as List? ?? const [])
          .map((item) => OrderItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      status: orderStatusFromString(json['status'] as String?),
      approvedByUid: json['approvedByUid'] as String?,
      approvedAt: _dateFromAny(json['approvedAt']),
      rejectedReason: json['rejectedReason'] as String?,
      dispatchedByUid: json['dispatchedByUid'] as String?,
      dispatchedAt: _dateFromAny(json['dispatchedAt']),
      deliveredAt: _dateFromAny(json['deliveredAt']),
      createdAt: _dateFromAny(json['createdAt']),
    );
  }

  /// For the initial (offline) create — server-assigned fields
  /// (`approvedByUid`, `dispatchedAt`, etc.) are deliberately omitted since
  /// only Firestore/the review actions ever set them.
  Map<String, dynamic> toCreateJson() {
    return {
      'agencyId': agencyId,
      'agencyName': agencyName,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'items': items.map((item) => item.toJson()).toList(),
      'totalValue': totalValue,
      'status': 'pending',
    };
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
  List<Object?> get props => [
        id,
        agencyId,
        agencyName,
        createdByUid,
        createdByName,
        items,
        status,
        approvedByUid,
        approvedAt,
        rejectedReason,
        dispatchedByUid,
        dispatchedAt,
        deliveredAt,
        createdAt,
      ];
}
