import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/doctor_visit_log.dart';

/// `DoctorVisitLogs`: append-only daily visit/feedback records, uploaded
/// directly by the MR's own client — mirrors [UsageSessionRemoteDataSource].
class DoctorVisitLogRemoteDataSource {
  DoctorVisitLogRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> upload(List<DoctorVisitLog> logs) async {
    debugPrint('DoctorVisitLogRemoteDataSource.upload: uploading ${logs.length} logs');
    if (logs.isEmpty) return;

    const chunkSize = 500;
    for (var i = 0; i < logs.length; i += chunkSize) {
      final batch = _firestore.batch();
      for (final log in logs.skip(i).take(chunkSize)) {
        final ref = _firestore.collection('DoctorVisitLogs').doc(log.id);
        batch.set(ref, {
          'mrUid': log.mrUid,
          'doctorId': log.doctorId,
          'doctorName': log.doctorName,
          'visitDate': log.visitDate,
          'visited': log.visited,
          'feedback': log.feedback,
          'latitude': log.latitude,
          'longitude': log.longitude,
          'createdAt': Timestamp.fromDate(log.createdAt),
          'samplesGiven': log.samplesGiven,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint('DoctorVisitLogRemoteDataSource.upload: committed batch of ${logs.skip(i).take(chunkSize).length}');
    }
  }

  /// For the admin/view_global_data dashboard: most recent 1000 visit logs
  /// across all MRs. A scoped manager should call [fetchRecentForEmployees]
  /// instead — see firestore.rules' `isInDownlineOf`.
  Future<List<DoctorVisitLog>> fetchRecent() async {
    debugPrint('DoctorVisitLogRemoteDataSource.fetchRecent: fetching up to 1000 recent logs');
    final snapshot =
        await _firestore.collection('DoctorVisitLogs').orderBy('createdAt', descending: true).limit(1000).get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  /// Visit logs belonging to exactly [mrUids] — see
  /// [UsageSessionRemoteDataSource.fetchRecentForEmployees] for why this is
  /// chunked and sorted client-side.
  Future<List<DoctorVisitLog>> fetchRecentForEmployees(List<String> mrUids) async {
    debugPrint('DoctorVisitLogRemoteDataSource.fetchRecentForEmployees: mrUids=${mrUids.length}');
    if (mrUids.isEmpty) return [];

    const chunkSize = 30;
    final logs = <DoctorVisitLog>[];
    for (var i = 0; i < mrUids.length; i += chunkSize) {
      final chunk = mrUids.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore.collection('DoctorVisitLogs').where('mrUid', whereIn: chunk).get();
      logs.addAll(snapshot.docs.map(_fromDoc));
    }
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    debugPrint('DoctorVisitLogRemoteDataSource.fetchRecentForEmployees: fetched ${logs.length} logs');
    return logs;
  }

  DoctorVisitLog _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return DoctorVisitLog(
      id: doc.id,
      mrUid: data['mrUid'] as String? ?? '',
      doctorId: data['doctorId'] as String? ?? '',
      doctorName: data['doctorName'] as String? ?? '',
      visitDate: data['visitDate'] as String? ?? '',
      visited: data['visited'] as bool? ?? false,
      feedback: data['feedback'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      samplesGiven: Map<String, int>.from(data['samplesGiven'] as Map? ?? const {}),
    );
  }
}
