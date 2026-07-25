import 'package:equatable/equatable.dart';

/// A catalog product. [departments] maps a department name to this
/// product's display position within that department (lower sorts first).
class Product extends Equatable {
  final String id;
  final String name;
  final String info;
  final Map<String, int> departments;
  final String imageUrl;

  const Product({
    required this.id,
    required this.name,
    required this.info,
    required this.departments,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      info: json['info'] as String? ?? '',
      departments: Map<String, int>.from(json['departments'] as Map? ?? {}),
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'info': info,
      'departments': departments,
      'imageUrl': imageUrl,
    };
  }

  int positionIn(String department) => departments[department] ?? 9999;

  @override
  List<Object?> get props => [id, name, info, departments, imageUrl];
}
