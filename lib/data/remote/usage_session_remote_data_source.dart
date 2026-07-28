import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/usage_session.dart';

/// Firestore side of MR usage sessions. Uploads use the session's own local
/// [UsageSession.id] as the Firestore doc id, so retrying an upload after a
/// partial failure is safe (it overwrites the same doc rather than
/// duplicating it). Reading them back (for the admin dashboard) is a plain
/// query — rules restrict this collection to admin reads.
class UsageSessionRemoteDataSource {
  UsageSessionRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> upload(List<UsageSession> sessions) async {
    debugPrint('UsageSessionRemoteDataSource.upload: uploading ${sessions.length} sessions');
    if (sessions.isEmpty) return;

    // Firestore caps a single batch at 500 writes; chunk so a device that's
    // been offline long enough to queue more than 500 sessions doesn't fail
    // the whole upload at once.
    const chunkSize = 500;
    for (var i = 0; i < sessions.length; i += chunkSize) {
      final batch = _firestore.batch();
      for (final session in sessions.skip(i).take(chunkSize)) {
        final ref = _firestore.collection('UsageSessions').doc(session.id);
        batch.set(ref, {
          'employeeUid': session.employeeUid,
          'username': session.username,
          'openedAt': Timestamp.fromDate(session.openedAt),
          'closedAt': session.closedAt == null ? null : Timestamp.fromDate(session.closedAt!),
          'durationSeconds': session.duration?.inSeconds,
          'latitude': session.latitude,
          'longitude': session.longitude,
          'uploadedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint('UsageSessionRemoteDataSource.upload: committed batch of ${sessions.skip(i).take(chunkSize).length} sessions');
    }
    debugPrint('UsageSessionRemoteDataSource.upload: upload complete for ${sessions.length} sessions');
  }

  /// Most recent 1000 sessions across all MRs — plenty for the dashboard's
  /// per-employee aggregates without an unbounded read as the log grows.
  /// Only readable by an admin/view_global_data holder (see firestore.rules)
  /// — a scoped manager should call [fetchRecentForEmployees] instead.
  Future<List<UsageSession>> fetchRecent() async {
    debugPrint('UsageSessionRemoteDataSource.fetchRecent: fetching up to 1000 recent UsageSessions');
    final snapshot =
        await _firestore.collection('UsageSessions').orderBy('openedAt', descending: true).limit(1000).get();
    debugPrint('UsageSessionRemoteDataSource.fetchRecent: fetched ${snapshot.docs.length} sessions');
    return snapshot.docs.map(_fromDoc).toList();
  }

  /// Sessions belonging to exactly [employeeUids] — what a manager without
  /// global visibility must use instead of [fetchRecent], since
  /// firestore.rules only lets them read a session doc whose `employeeUid`
  /// is in their own reporting-chain downline (see `isInDownlineOf` there).
  /// Firestore caps `whereIn` at 30 values, so a large team is fetched in
  /// chunks and merged; sorted client-side afterwards rather than in the
  /// query itself, which would need a composite index per chunk size.
  Future<List<UsageSession>> fetchRecentForEmployees(List<String> employeeUids) async {
    debugPrint('UsageSessionRemoteDataSource.fetchRecentForEmployees: employeeUids=${employeeUids.length}');
    if (employeeUids.isEmpty) return [];

    const chunkSize = 30;
    final sessions = <UsageSession>[];
    for (var i = 0; i < employeeUids.length; i += chunkSize) {
      final chunk = employeeUids.skip(i).take(chunkSize).toList();
      final snapshot = await _firestore.collection('UsageSessions').where('employeeUid', whereIn: chunk).get();
      sessions.addAll(snapshot.docs.map(_fromDoc));
    }
    sessions.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    debugPrint('UsageSessionRemoteDataSource.fetchRecentForEmployees: fetched ${sessions.length} sessions');
    return sessions;
  }

  UsageSession _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final openedAt = data['openedAt'] as Timestamp?;
    final closedAt = data['closedAt'] as Timestamp?;
    return UsageSession(
      id: doc.id,
      employeeUid: data['employeeUid'] as String? ?? '',
      username: data['username'] as String? ?? '',
      openedAt: openedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      closedAt: closedAt?.toDate(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }
}
