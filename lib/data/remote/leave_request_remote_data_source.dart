import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/leave_request.dart';

/// `LeaveRequests`: an MR creates one directly (low-privilege — firestore.
/// rules only lets them write their own `mrUid`, `status: pending`);
/// approve/reject are also direct writes, gated by `approve_leave` +
/// reporting-chain membership (or global visibility). Mirrors
/// [ExpenseClaimRemoteDataSource] exactly.
class LeaveRequestRemoteDataSource {
  LeaveRequestRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  LeaveRequest _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => LeaveRequest.fromJson(doc.id, doc.data());

  /// [localId] becomes the Firestore doc id, so a retried upload after a
  /// partial failure overwrites the same doc instead of duplicating it.
  Future<void> create(String localId, Map<String, dynamic> data) async {
    debugPrint('LeaveRequestRemoteDataSource.create: localId=$localId');
    await _firestore
        .collection('LeaveRequests')
        .doc(localId)
        .set({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<List<LeaveRequest>> fetchMine(String mrUid) async {
    debugPrint('LeaveRequestRemoteDataSource.fetchMine: mrUid=$mrUid');
    final snapshot = await _firestore.collection('LeaveRequests').where('mrUid', isEqualTo: mrUid).get();
    final requests = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return requests;
  }

  /// Every request — for an approver with global visibility. Mirrors
  /// [ExpenseClaimRemoteDataSource.fetchAll].
  Future<List<LeaveRequest>> fetchAll() async {
    debugPrint('LeaveRequestRemoteDataSource.fetchAll: querying all requests');
    final snapshot = await _firestore.collection('LeaveRequests').get();
    final requests = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return requests;
  }

  /// Every request filed by exactly [mrUids] — what a manager without
  /// global visibility must use instead. Mirrors
  /// [ExpenseClaimRemoteDataSource.fetchForEmployees]'s chunked-`whereIn`
  /// approach (Firestore caps `whereIn` at 30).
  Future<List<LeaveRequest>> fetchForEmployees(List<String> mrUids) async {
    debugPrint('LeaveRequestRemoteDataSource.fetchForEmployees: mrUids=${mrUids.length}');
    if (mrUids.isEmpty) return [];

    const chunkSize = 30;
    final requests = <LeaveRequest>[];
    for (var i = 0; i < mrUids.length; i += chunkSize) {
      final chunk = mrUids.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore.collection('LeaveRequests').where('mrUid', whereIn: chunk).get();
      requests.addAll(snapshot.docs.map(_fromDoc));
    }
    requests.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return requests;
  }

  Future<void> approve(String requestId, {required String approvedByUid}) async {
    debugPrint('LeaveRequestRemoteDataSource.approve: requestId=$requestId');
    await _firestore.collection('LeaveRequests').doc(requestId).update({
      'status': 'approved',
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(String requestId, {required String approvedByUid, String? reason}) async {
    debugPrint('LeaveRequestRemoteDataSource.reject: requestId=$requestId');
    await _firestore.collection('LeaveRequests').doc(requestId).update({
      'status': 'rejected',
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectedReason': reason,
    });
  }
}
