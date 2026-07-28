import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/entity_change_request.dart';

/// `EntityChangeRequests`: an MR proposes a new agency/pharmacy by writing
/// directly here; an Office Admin approves/rejects via the
/// `reviewEntityChangeRequest` Cloud Function, which is the only thing ever
/// allowed to apply it to `Agencies`/`Pharmacies` or flip its `status` — see
/// firestore.rules. Mirrors [DoctorChangeRequestRemoteDataSource].
class EntityChangeRequestRemoteDataSource {
  EntityChangeRequestRemoteDataSource({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<void> create(String localId, Map<String, dynamic> data) async {
    debugPrint('EntityChangeRequestRemoteDataSource.create: localId=$localId');
    await _firestore.collection('EntityChangeRequests').doc(localId).set(data);
  }

  Future<List<EntityChangeRequest>> fetchPending() async {
    debugPrint('EntityChangeRequestRemoteDataSource.fetchPending: querying pending requests');
    final snapshot =
        await _firestore.collection('EntityChangeRequests').where('status', isEqualTo: 'pending').get();
    final requests = snapshot.docs.map((doc) => EntityChangeRequest.fromJson(doc.id, doc.data())).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return requests;
  }

  Future<List<EntityChangeRequest>> fetchMine(String requestedByUid) async {
    debugPrint('EntityChangeRequestRemoteDataSource.fetchMine: requestedByUid=$requestedByUid');
    final snapshot = await _firestore
        .collection('EntityChangeRequests')
        .where('requestedByUid', isEqualTo: requestedByUid)
        .get();
    final requests = snapshot.docs.map((doc) => EntityChangeRequest.fromJson(doc.id, doc.data())).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return requests;
  }

  Future<void> review(String requestId, {required bool approve, String? reviewNote}) async {
    debugPrint('EntityChangeRequestRemoteDataSource.review: requestId=$requestId approve=$approve');
    await _functions.httpsCallable('reviewEntityChangeRequest').call({
      'requestId': requestId,
      'approve': approve,
      if (reviewNote != null && reviewNote.isNotEmpty) 'reviewNote': reviewNote,
    });
    debugPrint('EntityChangeRequestRemoteDataSource.review: succeeded requestId=$requestId');
  }
}
