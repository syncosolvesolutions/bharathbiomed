import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/product.dart';

/// Raw Firestore reads/writes for the catalog. Products live in the
/// `Products` collection; department names/order live in a single
/// `Department/departmentsDoc` document. Writes are only ever reached from
/// the admin section of the app — Firestore rules restrict them to the
/// admin account regardless of what the client sends.
class ProductRemoteDataSource {
  ProductRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Product>> fetchProducts() async {
    final snapshot = await _firestore.collection('Products').get();
    return snapshot.docs.map(_productFromDoc).toList();
  }

  Future<List<String>> fetchDepartments() async {
    final doc = await _firestore.collection('Department').doc('departmentsDoc').get();
    if (!doc.exists) return [];
    final data = doc.data();
    return List<String>.from(data?['departments'] as List? ?? []);
  }

  Product _productFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      info: data['info'] as String? ?? '',
      departments: Map<String, int>.from(data['departments'] as Map? ?? {}),
      imageUrl: data['imageUrl'] as String? ?? '',
    );
  }

  Future<String> addProduct({
    required String name,
    required String info,
    required Map<String, int> departments,
    required String imageUrl,
  }) async {
    final docRef = await _firestore.collection('Products').add({
      'name': name,
      'info': info,
      'departments': departments,
      'imageUrl': imageUrl,
    });
    return docRef.id;
  }

  Future<void> updateProduct(Product product) async {
    await _firestore.collection('Products').doc(product.id).update({
      'name': product.name,
      'info': product.info,
      'departments': product.departments,
      'imageUrl': product.imageUrl,
    });
  }

  Future<void> deleteProduct(String id) => _firestore.collection('Products').doc(id).delete();

  Future<void> addDepartment(String name) {
    return _firestore.collection('Department').doc('departmentsDoc').set(
      {
        'departments': FieldValue.arrayUnion([name]),
      },
      SetOptions(merge: true),
    );
  }

  /// Renames a department and migrates its position value on every product
  /// that references it, so existing catalog ordering survives the rename.
  Future<void> renameDepartment(String oldName, String newName) async {
    final departmentsDocRef = _firestore.collection('Department').doc('departmentsDoc');
    final doc = await departmentsDocRef.get();
    final departments = List<String>.from(doc.data()?['departments'] as List? ?? []);
    final index = departments.indexOf(oldName);
    if (index == -1) {
      throw Exception('Department "$oldName" no longer exists.');
    }
    departments[index] = newName;
    await departmentsDocRef.set({'departments': departments});
    await _migrateProductDepartmentKey(oldName, newName);
  }

  /// Removes a department and drops it from every product's department map.
  Future<void> deleteDepartment(String name) async {
    await _firestore.collection('Department').doc('departmentsDoc').update({
      'departments': FieldValue.arrayRemove([name]),
    });
    await _migrateProductDepartmentKey(name, null);
  }

  /// Renames [oldKey] to [newKey] in every product's `departments` map,
  /// preserving that product's position value. Passing `null` for [newKey]
  /// removes the key instead of renaming it.
  Future<void> _migrateProductDepartmentKey(String oldKey, String? newKey) async {
    final productsSnapshot = await _firestore.collection('Products').get();
    final updates = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>>[];
    for (final doc in productsSnapshot.docs) {
      final departments = Map<String, dynamic>.from(doc.data()['departments'] as Map? ?? {});
      if (!departments.containsKey(oldKey)) continue;
      final position = departments.remove(oldKey);
      if (newKey != null) departments[newKey] = position;
      updates.add(MapEntry(doc.reference, {'departments': departments}));
    }
    if (updates.isEmpty) return;

    // Firestore caps a single batch at 500 writes; chunk so a catalog with
    // more than 500 products referencing this department doesn't silently
    // fail partway through the migration.
    const chunkSize = 500;
    for (var i = 0; i < updates.length; i += chunkSize) {
      final batch = _firestore.batch();
      for (final entry in updates.skip(i).take(chunkSize)) {
        batch.update(entry.key, entry.value);
      }
      await batch.commit();
    }
  }
}
