import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/sales_target.dart';

/// `SalesTargets`: doc id is `{employeeUid}_{period}`, so setting a target
/// for the same employee/period again is a natural upsert rather than a
/// growing pile of duplicates. Only ever written by whoever holds
/// `manage_targets` (or has global visibility/is admin) for someone in their
/// own reporting chain — see firestore.rules.
class SalesTargetRemoteDataSource {
  SalesTargetRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String _docId(String employeeUid, String period) => '${employeeUid}_$period';

  Future<void> setTarget({
    required String employeeUid,
    required String period,
    required double targetValue,
    required String createdByUid,
  }) async {
    debugPrint('SalesTargetRemoteDataSource.setTarget: employeeUid=$employeeUid period=$period');
    await _firestore.collection('SalesTargets').doc(_docId(employeeUid, period)).set({
      'employeeUid': employeeUid,
      'period': period,
      'targetValue': targetValue,
      'createdByUid': createdByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<SalesTarget?> fetchForEmployee(String employeeUid, String period) async {
    debugPrint('SalesTargetRemoteDataSource.fetchForEmployee: employeeUid=$employeeUid period=$period');
    final doc = await _firestore.collection('SalesTargets').doc(_docId(employeeUid, period)).get();
    if (!doc.exists) return null;
    return SalesTarget.fromJson(doc.id, doc.data()!);
  }

  /// Every [employeeUids]' target for [period] — chunked `whereIn` on
  /// `employeeUid` only (mirrors
  /// [UsageSessionRemoteDataSource.fetchRecentForEmployees]), filtered to
  /// [period] client-side rather than adding a second `where` clause:
  /// Firestore would need a composite index for `whereIn` + equality
  /// together, and each employee only ever has a handful of target docs
  /// (one per month), so filtering the small result set in Dart avoids that
  /// deployment step entirely.
  Future<List<SalesTarget>> fetchForEmployees(List<String> employeeUids, String period) async {
    debugPrint('SalesTargetRemoteDataSource.fetchForEmployees: employeeUids=${employeeUids.length} period=$period');
    if (employeeUids.isEmpty) return [];

    const chunkSize = 30;
    final targets = <SalesTarget>[];
    for (var i = 0; i < employeeUids.length; i += chunkSize) {
      final chunk = employeeUids.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore.collection('SalesTargets').where('employeeUid', whereIn: chunk).get();
      targets.addAll(snapshot.docs.map((doc) => SalesTarget.fromJson(doc.id, doc.data())));
    }
    return targets.where((target) => target.period == period).toList();
  }
}
