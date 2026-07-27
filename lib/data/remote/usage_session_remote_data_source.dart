import 'package:cloud_firestore/cloud_firestore.dart';

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
    }
  }

  /// Most recent 1000 sessions across all MRs — plenty for the dashboard's
  /// per-employee aggregates without an unbounded read as the log grows.
  Future<List<UsageSession>> fetchRecent() async {
    final snapshot =
        await _firestore.collection('UsageSessions').orderBy('openedAt', descending: true).limit(1000).get();
    return snapshot.docs.map((doc) {
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
    }).toList();
  }
}
