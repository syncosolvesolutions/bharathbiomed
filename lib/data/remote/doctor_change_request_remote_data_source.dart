import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/doctor_change_request.dart';

/// `DoctorChangeRequests`: an MR proposes a doctor create/edit by writing
/// directly here (low-privilege — it's just a proposal, not yet live); the
/// admin approves/rejects via the `reviewDoctorChangeRequest` Cloud
/// Function, which is the only thing ever allowed to apply it to `Doctors`
/// or flip its `status` (see firestore.rules).
class DoctorChangeRequestRemoteDataSource {
  DoctorChangeRequestRemoteDataSource({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// [localId] becomes the Firestore doc id, so a retried upload after a
  /// partial failure overwrites the same doc instead of duplicating it.
  Future<void> create(String localId, Map<String, dynamic> data) async {
    debugPrint('DoctorChangeRequestRemoteDataSource.create: localId=$localId');
    await _firestore.collection('DoctorChangeRequests').doc(localId).set(data);
  }

  Future<List<DoctorChangeRequest>> fetchPending() async {
    debugPrint('DoctorChangeRequestRemoteDataSource.fetchPending: querying pending requests');
    final snapshot =
        await _firestore.collection('DoctorChangeRequests').where('status', isEqualTo: 'pending').get();
    debugPrint('DoctorChangeRequestRemoteDataSource.fetchPending: fetched ${snapshot.docs.length} requests');
    final requests = snapshot.docs.map((doc) => DoctorChangeRequest.fromJson(doc.id, doc.data())).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return requests;
  }

  Future<List<DoctorChangeRequest>> fetchMine(String requestedByUid) async {
    debugPrint('DoctorChangeRequestRemoteDataSource.fetchMine: requestedByUid=$requestedByUid');
    final snapshot =
        await _firestore.collection('DoctorChangeRequests').where('requestedByUid', isEqualTo: requestedByUid).get();
    final requests = snapshot.docs.map((doc) => DoctorChangeRequest.fromJson(doc.id, doc.data())).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return requests;
  }

  Future<void> review(String requestId, {required bool approve, String? reviewNote}) async {
    debugPrint('DoctorChangeRequestRemoteDataSource.review: requestId=$requestId approve=$approve');
    await _functions.httpsCallable('reviewDoctorChangeRequest').call({
      'requestId': requestId,
      'approve': approve,
      if (reviewNote != null && reviewNote.isNotEmpty) 'reviewNote': reviewNote,
    });
    debugPrint('DoctorChangeRequestRemoteDataSource.review: succeeded requestId=$requestId');
  }
}
