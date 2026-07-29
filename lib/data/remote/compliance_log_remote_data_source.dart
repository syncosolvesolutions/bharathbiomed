import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/compliance_log.dart';

/// `ComplianceLogs`: append-only UCPMP compliance records, uploaded
/// directly by the MR's own client — mirrors [RcpaRemoteDataSource].
class ComplianceLogRemoteDataSource {
  ComplianceLogRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> upload(List<ComplianceLog> logs) async {
    debugPrint('ComplianceLogRemoteDataSource.upload: uploading ${logs.length} logs');
    if (logs.isEmpty) return;

    const chunkSize = 500;
    for (var i = 0; i < logs.length; i += chunkSize) {
      final batch = _firestore.batch();
      for (final log in logs.skip(i).take(chunkSize)) {
        final ref = _firestore.collection('ComplianceLogs').doc(log.id);
        batch.set(ref, {...log.toJson(), 'createdAt': Timestamp.fromDate(log.createdAt)});
      }
      await batch.commit();
      debugPrint('ComplianceLogRemoteDataSource.upload: committed batch of ${logs.skip(i).take(chunkSize).length}');
    }
  }

  /// For the admin/view_global_data dashboard: most recent 1000 logs across
  /// all MRs. Mirrors [RcpaRemoteDataSource.fetchRecent].
  Future<List<ComplianceLog>> fetchRecent() async {
    debugPrint('ComplianceLogRemoteDataSource.fetchRecent: fetching up to 1000 recent logs');
    final snapshot =
        await _firestore.collection('ComplianceLogs').orderBy('createdAt', descending: true).limit(1000).get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  /// Logs filed by exactly [mrUids] — mirrors
  /// [RcpaRemoteDataSource.fetchRecentForEmployees].
  Future<List<ComplianceLog>> fetchRecentForEmployees(List<String> mrUids) async {
    debugPrint('ComplianceLogRemoteDataSource.fetchRecentForEmployees: mrUids=${mrUids.length}');
    if (mrUids.isEmpty) return [];

    const chunkSize = 30;
    final logs = <ComplianceLog>[];
    for (var i = 0; i < mrUids.length; i += chunkSize) {
      final chunk = mrUids.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore.collection('ComplianceLogs').where('mrUid', whereIn: chunk).get();
      logs.addAll(snapshot.docs.map(_fromDoc));
    }
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return logs;
  }

  ComplianceLog _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => ComplianceLog.fromJson(doc.id, doc.data());
}
