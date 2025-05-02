class Product {
  final String id;
  final String name;
  final String info;
  final Map<String, int>
      departments; // Updated: Now storing department positions
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.info,
    required this.departments,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      info: json['info'],
      departments:
          Map<String, int>.from(json['departments']), // Updated to handle Map
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'info': info,
      'departments': departments, // Updated to store as Map
      'imageUrl': imageUrl,
    };
  }
}
