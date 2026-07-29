import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/expense_claim.dart';

/// `ExpenseClaims`: an MR creates one directly (low-privilege — firestore.
/// rules only lets them write their own `mrUid`, `status: pending`);
/// approve/reject are also direct writes, gated by `approve_expenses` +
/// reporting-chain membership (or global visibility) — mirrors
/// [OrderRemoteDataSource], minus the dispatch Cloud Function since a claim
/// has no further fulfillment step once approved.
class ExpenseClaimRemoteDataSource {
  ExpenseClaimRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  ExpenseClaim _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => ExpenseClaim.fromJson(doc.id, doc.data());

  /// [localId] becomes the Firestore doc id, so a retried upload after a
  /// partial failure overwrites the same doc instead of duplicating it.
  Future<void> create(String localId, Map<String, dynamic> data) async {
    debugPrint('ExpenseClaimRemoteDataSource.create: localId=$localId');
    await _firestore
        .collection('ExpenseClaims')
        .doc(localId)
        .set({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<List<ExpenseClaim>> fetchMine(String mrUid) async {
    debugPrint('ExpenseClaimRemoteDataSource.fetchMine: mrUid=$mrUid');
    final snapshot = await _firestore.collection('ExpenseClaims').where('mrUid', isEqualTo: mrUid).get();
    final claims = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return claims;
  }

  /// Every claim — for an approver with global visibility. Mirrors
  /// [OrderRemoteDataSource.fetchAll].
  Future<List<ExpenseClaim>> fetchAll() async {
    debugPrint('ExpenseClaimRemoteDataSource.fetchAll: querying all claims');
    final snapshot = await _firestore.collection('ExpenseClaims').get();
    final claims = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return claims;
  }

  /// Every claim filed by exactly [mrUids] — what a manager without global
  /// visibility must use instead. Mirrors
  /// [OrderRemoteDataSource.fetchForEmployees]'s chunked-`whereIn` approach
  /// (Firestore caps `whereIn` at 30).
  Future<List<ExpenseClaim>> fetchForEmployees(List<String> mrUids) async {
    debugPrint('ExpenseClaimRemoteDataSource.fetchForEmployees: mrUids=${mrUids.length}');
    if (mrUids.isEmpty) return [];

    const chunkSize = 30;
    final claims = <ExpenseClaim>[];
    for (var i = 0; i < mrUids.length; i += chunkSize) {
      final chunk = mrUids.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore.collection('ExpenseClaims').where('mrUid', whereIn: chunk).get();
      claims.addAll(snapshot.docs.map(_fromDoc));
    }
    claims.sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    return claims;
  }

  Future<void> approve(String claimId, {required String approvedByUid}) async {
    debugPrint('ExpenseClaimRemoteDataSource.approve: claimId=$claimId');
    await _firestore.collection('ExpenseClaims').doc(claimId).update({
      'status': 'approved',
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(String claimId, {required String approvedByUid, String? reason}) async {
    debugPrint('ExpenseClaimRemoteDataSource.reject: claimId=$claimId');
    await _firestore.collection('ExpenseClaims').doc(claimId).update({
      'status': 'rejected',
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectedReason': reason,
    });
  }
}
