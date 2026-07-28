import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/doctor_visit_plan.dart';

/// `DoctorVisitPlans/{mrUid}`: one doc per MR holding their recurring weekly
/// schedule. The MR edits their own doc directly (low-privilege, it only
/// references doctor ids already assigned to them); the admin can read/edit
/// any MR's plan too — see firestore.rules.
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
}
