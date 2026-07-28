import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/agency.dart';

/// Raw Firestore reads/writes for the `Agencies` collection. Only an Office
/// Admin can create/deactivate one directly; updating is also open to
/// whoever holds `manage_agencies` (see firestore.rules). An MR's proposed
/// new agency instead goes through `EntityChangeRequests` and is only ever
/// applied here by the `reviewEntityChangeRequest` Cloud Function.
class AgencyRemoteDataSource {
  AgencyRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Agency>> fetchAll() async {
    debugPrint('AgencyRemoteDataSource.fetchAll: fetching Agencies collection');
    final snapshot = await _firestore.collection('Agencies').get();
    debugPrint('AgencyRemoteDataSource.fetchAll: fetched ${snapshot.docs.length} agencies');
    return snapshot.docs.map((doc) => Agency.fromJson(doc.id, doc.data())).toList();
  }

  Future<String> addAgency(Agency agency) async {
    debugPrint('AgencyRemoteDataSource.addAgency: name=${agency.name}');
    final docRef = await _firestore.collection('Agencies').add({
      ...agency.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('AgencyRemoteDataSource.addAgency: added docId=${docRef.id}');
    return docRef.id;
  }

  Future<void> updateAgency(Agency agency) async {
    debugPrint('AgencyRemoteDataSource.updateAgency: docId=${agency.id}');
    await _firestore.collection('Agencies').doc(agency.id).update({
      ...agency.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Office-Admin-only in firestore.rules — flips [Agency.active] rather
  /// than deleting, so its order history stays intact.
  Future<void> setActive(String id, {required bool active}) async {
    debugPrint('AgencyRemoteDataSource.setActive: id=$id active=$active');
    await _firestore.collection('Agencies').doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
