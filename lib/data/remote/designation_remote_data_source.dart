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
    return snapshot.docs.map((doc) => Designation.fromJson(doc.id, doc.data())).toList();
  }

  Future<String> add(Map<String, dynamic> data) async {
    debugPrint('DesignationRemoteDataSource.add: adding designation data=$data');
    final ref = await _collection.add(data);
    debugPrint('DesignationRemoteDataSource.add: added designation docId=${ref.id}');
    return ref.id;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    debugPrint('DesignationRemoteDataSource.update: updating designation docId=$id data=$data');
    await _collection.doc(id).update(data);
    debugPrint('DesignationRemoteDataSource.update: updated designation docId=$id');
  }

  /// Batch-updates `parentDesignationId` on a set of designations in one
  /// commit — used to write back the "reports to this designation" downline
  /// checkboxes from `DesignationFormScreen`.
  Future<void> updateParents(Map<String, String?> parentDesignationIdByChildId) async {
    debugPrint('DesignationRemoteDataSource.updateParents: updating ${parentDesignationIdByChildId.length} children');
    final batch = _firestore.batch();
    for (final entry in parentDesignationIdByChildId.entries) {
      batch.update(_collection.doc(entry.key), {'parentDesignationId': entry.value});
    }
    await batch.commit();
    debugPrint('DesignationRemoteDataSource.updateParents: done');
  }

  /// Whether any `Users` doc currently has `designationId == id` — used by
  /// [DesignationRepository.delete] to block deleting a designation that's
  /// still assigned to someone.
  Future<bool> isAssignedToAnyEmployee(String id) async {
    debugPrint('DesignationRemoteDataSource.isAssignedToAnyEmployee: checking docId=$id');
    final snapshot = await _firestore.collection('Users').where('designationId', isEqualTo: id).limit(1).get();
    debugPrint('DesignationRemoteDataSource.isAssignedToAnyEmployee: docId=$id inUse=${snapshot.docs.isNotEmpty}');
    return snapshot.docs.isNotEmpty;
  }

  Future<void> delete(String id) async {
    debugPrint('DesignationRemoteDataSource.delete: deleting designation docId=$id');
    await _collection.doc(id).delete();
    debugPrint('DesignationRemoteDataSource.delete: deleted designation docId=$id');
  }
}
