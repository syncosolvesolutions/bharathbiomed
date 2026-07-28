import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/rcpa_entry.dart';

/// `RcpaEntries`: append-only Retail Chemist Prescription Audit records,
/// uploaded directly by the MR's own client — mirrors
/// [DoctorVisitLogRemoteDataSource].
class RcpaRemoteDataSource {
  RcpaRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> upload(List<RcpaEntry> entries) async {
    debugPrint('RcpaRemoteDataSource.upload: uploading ${entries.length} entries');
    if (entries.isEmpty) return;

    const chunkSize = 500;
    for (var i = 0; i < entries.length; i += chunkSize) {
      final batch = _firestore.batch();
      for (final entry in entries.skip(i).take(chunkSize)) {
        final ref = _firestore.collection('RcpaEntries').doc(entry.id);
        batch.set(ref, {...entry.toJson(), 'createdAt': Timestamp.fromDate(entry.createdAt)});
      }
      await batch.commit();
      debugPrint('RcpaRemoteDataSource.upload: committed batch of ${entries.skip(i).take(chunkSize).length}');
    }
  }

  /// For the admin/view_global_data dashboard: most recent 1000 entries
  /// across all MRs. A scoped manager should call [fetchRecentForEmployees]
  /// instead — see firestore.rules' `isInDownlineOf`.
  Future<List<RcpaEntry>> fetchRecent() async {
    debugPrint('RcpaRemoteDataSource.fetchRecent: fetching up to 1000 recent entries');
    final snapshot =
        await _firestore.collection('RcpaEntries').orderBy('createdAt', descending: true).limit(1000).get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  /// Entries logged by exactly [mrUids] — mirrors
  /// [UsageSessionRemoteDataSource.fetchRecentForEmployees].
  Future<List<RcpaEntry>> fetchRecentForEmployees(List<String> mrUids) async {
    debugPrint('RcpaRemoteDataSource.fetchRecentForEmployees: mrUids=${mrUids.length}');
    if (mrUids.isEmpty) return [];

    const chunkSize = 30;
    final entries = <RcpaEntry>[];
    for (var i = 0; i < mrUids.length; i += chunkSize) {
      final chunk = mrUids.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore.collection('RcpaEntries').where('mrUid', whereIn: chunk).get();
      entries.addAll(snapshot.docs.map(_fromDoc));
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  RcpaEntry _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) => RcpaEntry.fromJson(doc.id, doc.data());
}
