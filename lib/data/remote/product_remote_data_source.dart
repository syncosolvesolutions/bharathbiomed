import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/date_of_birth.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_batch.dart';

/// Raw Firestore reads/writes for the catalog. Products live in the
/// `Products` collection; department names/order live in a single
/// `Department/departmentsDoc` document. Writes are only ever reached from
/// the admin section of the app — Firestore rules restrict them to the
/// admin account regardless of what the client sends.
class ProductRemoteDataSource {
  ProductRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Product>> fetchProducts() async {
    debugPrint('ProductRemoteDataSource.fetchProducts: fetching Products collection');
    final snapshot = await _firestore.collection('Products').get();
    debugPrint('ProductRemoteDataSource.fetchProducts: fetched ${snapshot.docs.length} products');
    return snapshot.docs.map(_productFromDoc).toList();
  }

  Future<List<String>> fetchDepartments() async {
    debugPrint('ProductRemoteDataSource.fetchDepartments: fetching Department/departmentsDoc');
    final doc = await _firestore.collection('Department').doc('departmentsDoc').get();
    if (!doc.exists) {
      debugPrint('ProductRemoteDataSource.fetchDepartments: departmentsDoc does not exist');
      return [];
    }
    final data = doc.data();
    final departments = List<String>.from(data?['departments'] as List? ?? []);
    debugPrint('ProductRemoteDataSource.fetchDepartments: fetched ${departments.length} departments');
    return departments;
  }

  Product _productFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      info: data['info'] as String? ?? '',
      departments: Map<String, int>.from(data['departments'] as Map? ?? {}),
      imageUrl: data['imageUrl'] as String? ?? '',
      stockQuantity: (data['stockQuantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Adjusts a product's stock by [delta] (positive for stock received,
  /// negative for a manual correction) — a Firestore-side atomic increment
  /// so two concurrent adjustments (or a dispatch happening at the same
  /// time) can never race and clobber each other the way a read-then-write
  /// would. `dispatchOrder` (Cloud Function) uses the same increment
  /// mechanism to decrement stock when an order ships.
  Future<void> adjustStock(String productId, int delta) async {
    debugPrint('ProductRemoteDataSource.adjustStock: productId=$productId delta=$delta');
    await _firestore.collection('Products').doc(productId).update({
      'stockQuantity': FieldValue.increment(delta),
    });
  }

  Future<String> addProduct({
    required String name,
    required String info,
    required Map<String, int> departments,
    required String imageUrl,
    double unitPrice = 0,
  }) async {
    debugPrint('ProductRemoteDataSource.addProduct: adding product name=$name');
    final docRef = await _firestore.collection('Products').add({
      'name': name,
      'info': info,
      'departments': departments,
      'imageUrl': imageUrl,
      'unitPrice': unitPrice,
    });
    debugPrint('ProductRemoteDataSource.addProduct: added product docId=${docRef.id}');
    return docRef.id;
  }

  Future<void> updateProduct(Product product) async {
    debugPrint('ProductRemoteDataSource.updateProduct: updating product docId=${product.id}');
    await _firestore.collection('Products').doc(product.id).update({
      'name': product.name,
      'info': product.info,
      'departments': product.departments,
      'imageUrl': product.imageUrl,
      'unitPrice': product.unitPrice,
    });
    debugPrint('ProductRemoteDataSource.updateProduct: updated product docId=${product.id}');
  }

  Future<void> deleteProduct(String id) async {
    debugPrint('ProductRemoteDataSource.deleteProduct: deleting product docId=$id');
    await _firestore.collection('Products').doc(id).delete();
    debugPrint('ProductRemoteDataSource.deleteProduct: deleted product docId=$id');
  }

  /// Every batch for [productId], oldest expiry first — the same ordering
  /// `dispatchOrder` (Cloud Function) consumes in (FEFO: First-Expiry-
  /// First-Out).
  Future<List<ProductBatch>> fetchBatches(String productId) async {
    debugPrint('ProductRemoteDataSource.fetchBatches: productId=$productId');
    final snapshot = await _firestore
        .collection('Products')
        .doc(productId)
        .collection('Batches')
        .orderBy('expiryDate')
        .get();
    return snapshot.docs.map((doc) => ProductBatch.fromJson(doc.id, productId, doc.data())).toList();
  }

  /// Records a newly-received batch and, in the same transaction, adds its
  /// quantity onto `Products.stockQuantity` — a batch represents genuinely
  /// new stock arriving, so the two must move together. Compare
  /// [adjustStock], a plain manual correction that deliberately does *not*
  /// touch any batch (there's no batch to attribute a correction to).
  Future<void> addBatch(
    String productId, {
    required String batchNumber,
    required String expiryDate,
    required int quantity,
  }) async {
    debugPrint('ProductRemoteDataSource.addBatch: productId=$productId batchNumber=$batchNumber quantity=$quantity');
    final productRef = _firestore.collection('Products').doc(productId);
    final batchRef = productRef.collection('Batches').doc();
    await _firestore.runTransaction((transaction) async {
      transaction.set(batchRef, {
        'batchNumber': batchNumber,
        'expiryDate': expiryDate,
        'quantity': quantity,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(productRef, {'stockQuantity': FieldValue.increment(quantity)});
    });
    debugPrint('ProductRemoteDataSource.addBatch: added batchId=${batchRef.id}');
  }

  /// Removes a batch and, in the same transaction, subtracts whatever
  /// quantity it still held from `Products.stockQuantity` — mirrors
  /// [addBatch]'s "the two move together" rule. If this batch was already
  /// partially consumed by `dispatchOrder`'s FEFO decrement, only its
  /// *remaining* quantity is subtracted, which is correct: the consumed
  /// portion was already subtracted from `stockQuantity` at dispatch time.
  Future<void> deleteBatch(String productId, String batchId) async {
    debugPrint('ProductRemoteDataSource.deleteBatch: productId=$productId batchId=$batchId');
    final productRef = _firestore.collection('Products').doc(productId);
    final batchRef = productRef.collection('Batches').doc(batchId);
    await _firestore.runTransaction((transaction) async {
      final batchDoc = await transaction.get(batchRef);
      if (!batchDoc.exists) return;
      final remainingQuantity = (batchDoc.data()?['quantity'] as num?)?.toInt() ?? 0;
      transaction.delete(batchRef);
      if (remainingQuantity != 0) {
        transaction.update(productRef, {'stockQuantity': FieldValue.increment(-remainingQuantity)});
      }
    });
    debugPrint('ProductRemoteDataSource.deleteBatch: deleted batchId=$batchId');
  }

  /// Every batch across every product expiring on or before today +
  /// [withinDays] — powers the admin's expiry-alert view. A `collectionGroup`
  /// query, so it reaches every product's `Batches` subcollection in one
  /// call rather than fetching each product's batches individually.
  /// `expiryDate` is a zero-padded ISO string, so a plain string range
  /// comparison sorts chronologically without needing a `Timestamp`.
  Future<List<ProductBatch>> fetchExpiringWithinDays(int withinDays) async {
    debugPrint('ProductRemoteDataSource.fetchExpiringWithinDays: withinDays=$withinDays');
    final cutoff = isoFromDate(DateTime.now().add(Duration(days: withinDays)));
    final snapshot =
        await _firestore.collectionGroup('Batches').where('expiryDate', isLessThanOrEqualTo: cutoff).get();
    return snapshot.docs.map((doc) {
      // `Products/{productId}/Batches/{batchId}` — the product id is the
      // batch document's grandparent path segment.
      final productId = doc.reference.parent.parent?.id ?? '';
      return ProductBatch.fromJson(doc.id, productId, doc.data());
    }).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  }

  Future<void> addDepartment(String name) async {
    debugPrint('ProductRemoteDataSource.addDepartment: adding department name=$name');
    await _firestore.collection('Department').doc('departmentsDoc').set(
      {
        'departments': FieldValue.arrayUnion([name]),
      },
      SetOptions(merge: true),
    );
    debugPrint('ProductRemoteDataSource.addDepartment: added department name=$name');
  }

  /// Renames a department and migrates its position value on every product
  /// that references it, so existing catalog ordering survives the rename.
  Future<void> renameDepartment(String oldName, String newName) async {
    debugPrint('ProductRemoteDataSource.renameDepartment: renaming department oldName=$oldName newName=$newName');
    final departmentsDocRef = _firestore.collection('Department').doc('departmentsDoc');
    final doc = await departmentsDocRef.get();
    final departments = List<String>.from(doc.data()?['departments'] as List? ?? []);
    final index = departments.indexOf(oldName);
    if (index == -1) {
      throw Exception('Department "$oldName" no longer exists.');
    }
    departments[index] = newName;
    await departmentsDocRef.set({'departments': departments});
    debugPrint('ProductRemoteDataSource.renameDepartment: departmentsDoc updated, migrating product keys');
    await _migrateProductDepartmentKey(oldName, newName);
    debugPrint('ProductRemoteDataSource.renameDepartment: rename complete oldName=$oldName newName=$newName');
  }

  /// Removes a department and drops it from every product's department map.
  Future<void> deleteDepartment(String name) async {
    debugPrint('ProductRemoteDataSource.deleteDepartment: deleting department name=$name');
    await _firestore.collection('Department').doc('departmentsDoc').update({
      'departments': FieldValue.arrayRemove([name]),
    });
    debugPrint('ProductRemoteDataSource.deleteDepartment: departmentsDoc updated, migrating product keys');
    await _migrateProductDepartmentKey(name, null);
    debugPrint('ProductRemoteDataSource.deleteDepartment: delete complete name=$name');
  }

  /// Renames [oldKey] to [newKey] in every product's `departments` map,
  /// preserving that product's position value. Passing `null` for [newKey]
  /// removes the key instead of renaming it.
  Future<void> _migrateProductDepartmentKey(String oldKey, String? newKey) async {
    debugPrint('ProductRemoteDataSource._migrateProductDepartmentKey: oldKey=$oldKey newKey=$newKey');
    final productsSnapshot = await _firestore.collection('Products').get();
    final updates = <MapEntry<DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>>[];
    for (final doc in productsSnapshot.docs) {
      final departments = Map<String, dynamic>.from(doc.data()['departments'] as Map? ?? {});
      if (!departments.containsKey(oldKey)) continue;
      final position = departments.remove(oldKey);
      if (newKey != null) departments[newKey] = position;
      updates.add(MapEntry(doc.reference, {'departments': departments}));
    }
    if (updates.isEmpty) {
      debugPrint('ProductRemoteDataSource._migrateProductDepartmentKey: no products reference oldKey=$oldKey');
      return;
    }

    // Firestore caps a single batch at 500 writes; chunk so a catalog with
    // more than 500 products referencing this department doesn't silently
    // fail partway through the migration.
    const chunkSize = 500;
    debugPrint('ProductRemoteDataSource._migrateProductDepartmentKey: migrating ${updates.length} products');
    for (var i = 0; i < updates.length; i += chunkSize) {
      final batch = _firestore.batch();
      for (final entry in updates.skip(i).take(chunkSize)) {
        batch.update(entry.key, entry.value);
      }
      await batch.commit();
    }
    debugPrint('ProductRemoteDataSource._migrateProductDepartmentKey: migration complete for ${updates.length} products');
  }
}
