import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/doctor_visit_plan.dart';

/// `DoctorVisitPlans/{mrUid}`: one doc per MR holding their recurring weekly
/// schedule. The MR edits their own doc directly (low-privilege, it only
/// references doctor ids already assigned to them) and can submit it for
/// manager approval; a manager holding `approve_requests` (or the admin)
/// approves/rejects — see firestore.rules, which blocks content edits while
/// a review is pending.
class DoctorVisitPlanRemoteDataSource {
  DoctorVisitPlanRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<DoctorVisitPlan> fetch(String mrUid) async {
    debugPrint('DoctorVisitPlanRemoteDataSource.fetch: mrUid=$mrUid');
    final doc = await _firestore.collection('DoctorVisitPlans').doc(mrUid).get();
    if (!doc.exists) return DoctorVisitPlan(mrUid: mrUid);
    return DoctorVisitPlan.fromJson(mrUid, doc.data()!);
  }

  Future<void> save(DoctorVisitPlan plan) async {
    debugPrint('DoctorVisitPlanRemoteDataSource.save: mrUid=${plan.mrUid}');
    await _firestore.collection('DoctorVisitPlans').doc(plan.mrUid).set({
      ...plan.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Every plan currently awaiting a decision — for an approver with global
  /// visibility. Mirrors [OrderRemoteDataSource.fetchAll]'s "fetch broadly,
  /// let the caller scope it" shape, but filtered server-side by `status`
  /// (a single equality filter is allowed alongside the doc-id `whereIn`
  /// used by [fetchPendingForEmployees], unlike a second field filter would
  /// be) since there's no separate uid field to filter by — the doc id
  /// already is the mrUid.
  Future<List<DoctorVisitPlan>> fetchAllPending() async {
    debugPrint('DoctorVisitPlanRemoteDataSource.fetchAllPending: querying all pending plans');
    final snapshot = await _firestore.collection('DoctorVisitPlans').where('status', isEqualTo: 'pending').get();
    return snapshot.docs.map((doc) => DoctorVisitPlan.fromJson(doc.id, doc.data())).toList();
  }

  /// Pending plans belonging to exactly [mrUids] — what a manager without
  /// global visibility must use instead. Filters by document id (the doc id
  /// *is* the mrUid here, unlike [OrderRemoteDataSource.fetchForEmployees]'s
  /// separate `createdByUid` field) via [FieldPath.documentId], chunked at
  /// Firestore's 30-item `whereIn` cap.
  Future<List<DoctorVisitPlan>> fetchPendingForEmployees(List<String> mrUids) async {
    debugPrint('DoctorVisitPlanRemoteDataSource.fetchPendingForEmployees: mrUids=${mrUids.length}');
    if (mrUids.isEmpty) return [];

    const chunkSize = 30;
    final plans = <DoctorVisitPlan>[];
    for (var i = 0; i < mrUids.length; i += chunkSize) {
      final chunk = mrUids.skip(i).take(chunkSize).toList();
      final snapshot =
          await _firestore.collection('DoctorVisitPlans').where(FieldPath.documentId, whereIn: chunk).get();
      plans.addAll(snapshot.docs
          .map((doc) => DoctorVisitPlan.fromJson(doc.id, doc.data()))
          .where((plan) => plan.status == VisitPlanStatus.pending));
    }
    return plans;
  }

  /// A narrow `update` (not the MR's full-document `set` in [save]) so
  /// firestore.rules can restrict it to just the review fields — mirrors
  /// [OrderRemoteDataSource.approve].
  Future<void> approve(String mrUid, {required String approvedByUid}) async {
    debugPrint('DoctorVisitPlanRemoteDataSource.approve: mrUid=$mrUid');
    await _firestore.collection('DoctorVisitPlans').doc(mrUid).update({
      'status': 'approved',
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(String mrUid, {required String approvedByUid, String? reason}) async {
    debugPrint('DoctorVisitPlanRemoteDataSource.reject: mrUid=$mrUid');
    await _firestore.collection('DoctorVisitPlans').doc(mrUid).update({
      'status': 'rejected',
      'approvedByUid': approvedByUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectedReason': reason,
    });
  }
}
