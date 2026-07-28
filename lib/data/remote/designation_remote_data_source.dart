import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/designation.dart';

/// Raw Firestore CRUD for the `Designations` collection — the admin-managed
/// list of job titles assignable to employees. Firestore rules restrict this
/// collection to the admin account, so no read-side gating is needed here.
class DesignationRemoteDataSource {
  DesignationRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('Designations');

  Future<List<Designation>> fetchAll() async {
    debugPrint('DesignationRemoteDataSource.fetchAll: fetching Designations collection ordered by name');
    final snapshot = await _collection.orderBy('name').get();
    debugPrint('DesignationRemoteDataSource.fetchAll: fetched ${snapshot.docs.length} designations');
    return snapshot.docs.map((doc) => Designation(id: doc.id, name: doc.data()['name'] as String? ?? '')).toList();
  }

  Future<void> add(String name) async {
    debugPrint('DesignationRemoteDataSource.add: adding designation name=$name');
    await _collection.add({'name': name});
    debugPrint('DesignationRemoteDataSource.add: added designation name=$name');
  }

  Future<void> update(String id, String name) async {
    debugPrint('DesignationRemoteDataSource.update: updating designation docId=$id name=$name');
    await _collection.doc(id).update({'name': name});
    debugPrint('DesignationRemoteDataSource.update: updated designation docId=$id');
  }

  Future<void> delete(String id) async {
    debugPrint('DesignationRemoteDataSource.delete: deleting designation docId=$id');
    await _collection.doc(id).delete();
    debugPrint('DesignationRemoteDataSource.delete: deleted designation docId=$id');
  }
}
