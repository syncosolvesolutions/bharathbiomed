import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A catalog product. [departments] maps a department name to this
/// product's display position within that department (lower sorts first).
/// [stockQuantity] is managed separately from the rest of this model — see
/// `ProductRepository.adjustStock`/`ManageInventoryScreen` — new products
/// start at 0 and it's only ever changed there (an admin recording stock
/// received) or by `dispatchOrder` (a Cloud Function decrementing it when an
/// order ships), never through the product create/edit form.
class Product extends Equatable {
  final String id;
  final String name;
  final String info;
  final Map<String, int> departments;
  final String imageUrl;
  final int stockQuantity;

  /// Per-unit list price used to prefill an [OrderItem] when an MR places an
  /// order — still editable per line at order time, so a negotiated price
  /// doesn't require a catalog change. Defaults to 0 for products that
  /// predate order-taking (an MR must fill it in manually until an admin
  /// sets a real price).
  final double unitPrice;

  const Product({
    required this.id,
    required this.name,
    required this.info,
    required this.departments,
    required this.imageUrl,
    this.stockQuantity = 0,
    this.unitPrice = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    debugPrint('Product.fromJson: parsing product document id=${json['id']}');
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      info: json['info'] as String? ?? '',
      departments: Map<String, int>.from(json['departments'] as Map? ?? {}),
      imageUrl: json['imageUrl'] as String? ?? '',
      stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'info': info,
      'departments': departments,
      'imageUrl': imageUrl,
      'stockQuantity': stockQuantity,
      'unitPrice': unitPrice,
    };
  }

  int positionIn(String department) => departments[department] ?? 9999;

  @override
  List<Object?> get props => [id, name, info, departments, imageUrl, stockQuantity, unitPrice];
}
