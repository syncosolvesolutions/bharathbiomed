import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/pharmacy.dart';

/// Raw Firestore reads/writes for the `Pharmacies` collection — mirrors
/// [AgencyRemoteDataSource] exactly (same Office-Admin-create,
/// manage_agencies-update, EntityChangeRequests-for-MR-proposals shape).
class PharmacyRemoteDataSource {
  PharmacyRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<Pharmacy>> fetchAll() async {
    debugPrint('PharmacyRemoteDataSource.fetchAll: fetching Pharmacies collection');
    final snapshot = await _firestore.collection('Pharmacies').get();
    debugPrint('PharmacyRemoteDataSource.fetchAll: fetched ${snapshot.docs.length} pharmacies');
    return snapshot.docs.map((doc) => Pharmacy.fromJson(doc.id, doc.data())).toList();
  }

  Future<String> addPharmacy(Pharmacy pharmacy) async {
    debugPrint('PharmacyRemoteDataSource.addPharmacy: name=${pharmacy.name}');
    final docRef = await _firestore.collection('Pharmacies').add({
      ...pharmacy.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('PharmacyRemoteDataSource.addPharmacy: added docId=${docRef.id}');
    return docRef.id;
  }

  Future<void> updatePharmacy(Pharmacy pharmacy) async {
    debugPrint('PharmacyRemoteDataSource.updatePharmacy: docId=${pharmacy.id}');
    await _firestore.collection('Pharmacies').doc(pharmacy.id).update({
      ...pharmacy.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setActive(String id, {required bool active}) async {
    debugPrint('PharmacyRemoteDataSource.setActive: id=$id active=$active');
    await _firestore.collection('Pharmacies').doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
