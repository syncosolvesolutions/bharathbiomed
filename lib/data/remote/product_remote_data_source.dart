import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/product.dart';

/// Raw Firestore reads for the catalog. Products live in the `Products`
/// collection; department names/order live in a single
/// `Department/departmentsDoc` document.
class ProductRemoteDataSource {
  ProductRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Product>> fetchProducts() async {
    final snapshot = await _firestore.collection('Products').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Product(
        id: doc.id,
        name: data['name'] as String? ?? '',
        info: data['info'] as String? ?? '',
        departments: Map<String, int>.from(data['departments'] as Map? ?? {}),
        imageUrl: data['imageUrl'] as String? ?? '',
      );
    }).toList();
  }

  Future<List<String>> fetchDepartments() async {
    final doc = await _firestore.collection('Department').doc('departmentsDoc').get();
    if (!doc.exists) return [];
    final data = doc.data();
    return List<String>.from(data?['departments'] as List? ?? []);
  }
}
