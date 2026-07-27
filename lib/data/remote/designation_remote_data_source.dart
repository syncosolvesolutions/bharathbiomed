import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/designation.dart';

/// Raw Firestore CRUD for the `Designations` collection — the admin-managed
/// list of job titles assignable to employees. Firestore rules restrict this
/// collection to the admin account, so no read-side gating is needed here.
class DesignationRemoteDataSource {
  DesignationRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('Designations');

  Future<List<Designation>> fetchAll() async {
    final snapshot = await _collection.orderBy('name').get();
    return snapshot.docs.map((doc) => Designation(id: doc.id, name: doc.data()['name'] as String? ?? '')).toList();
  }

  Future<void> add(String name) => _collection.add({'name': name});

  Future<void> update(String id, String name) => _collection.doc(id).update({'name': name});

  Future<void> delete(String id) => _collection.doc(id).delete();
}
