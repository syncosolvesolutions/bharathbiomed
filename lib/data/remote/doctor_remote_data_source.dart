import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/doctor.dart';

/// Raw Firestore reads/writes for the `Doctors` collection. Only the admin
/// ever writes here directly (creating/editing a doctor outright, assigning/
/// reassigning an MR) — an MR's proposed create/edit instead goes through
/// `DoctorChangeRequests` and is only ever applied here by the
/// `reviewDoctorChangeRequest` Cloud Function once approved. See
/// firestore.rules for the enforcement.
class DoctorRemoteDataSource {
  DoctorRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Doctor _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => Doctor.fromJson(doc.id, doc.data());

  /// The admin's live view of every doctor, regardless of assignment.
  Future<List<Doctor>> fetchAll() async {
    debugPrint('DoctorRemoteDataSource.fetchAll: fetching Doctors collection');
    final snapshot = await _firestore.collection('Doctors').get();
    debugPrint('DoctorRemoteDataSource.fetchAll: fetched ${snapshot.docs.length} doctors');
    return snapshot.docs.map(_fromDoc).toList();
  }

  /// An MR's own view: only the doctors currently assigned to them.
  Future<List<Doctor>> fetchAssignedTo(String mrUid) async {
    debugPrint('DoctorRemoteDataSource.fetchAssignedTo: mrUid=$mrUid');
    final snapshot = await _firestore.collection('Doctors').where('assignedMrUid', isEqualTo: mrUid).get();
    debugPrint('DoctorRemoteDataSource.fetchAssignedTo: fetched ${snapshot.docs.length} doctors');
    return snapshot.docs.map(_fromDoc).toList();
  }

  Future<String> addDoctor(Doctor doctor) async {
    debugPrint('DoctorRemoteDataSource.addDoctor: name=${doctor.name}');
    final docRef = await _firestore.collection('Doctors').add({
      ...doctor.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('DoctorRemoteDataSource.addDoctor: added docId=${docRef.id}');
    return docRef.id;
  }

  Future<void> updateDoctor(Doctor doctor) async {
    debugPrint('DoctorRemoteDataSource.updateDoctor: docId=${doctor.id}');
    await _firestore.collection('Doctors').doc(doctor.id).update({
      ...doctor.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reassigns a doctor to a different MR (or unassigns with `null`) without
  /// touching anything else — requirement 8: "Admin can update doctors
  /// assigned to MR".
  Future<void> assignMr(String doctorId, {required String? mrUid, required String? mrName}) async {
    debugPrint('DoctorRemoteDataSource.assignMr: doctorId=$doctorId mrUid=$mrUid');
    await _firestore.collection('Doctors').doc(doctorId).update({
      'assignedMrUid': mrUid,
      'assignedMrName': mrName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDoctor(String id) async {
    debugPrint('DoctorRemoteDataSource.deleteDoctor: id=$id');
    await _firestore.collection('Doctors').doc(id).delete();
  }
}
