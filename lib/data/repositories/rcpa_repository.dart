import 'package:flutter/foundation.dart';

import '../../domain/models/rcpa_entry.dart';
import '../local/rcpa_local_data_source.dart';
import '../remote/rcpa_remote_data_source.dart';

/// RCPA entries, offline-first — mirrors [DoctorVisitLogRepository] exactly:
/// [logEntry] only ever writes locally (works standing in a pharmacy with no
/// signal), [uploadPending] is what the sync pipeline calls to reach
/// Firestore.
class RcpaRepository {
  RcpaRepository({RcpaLocalDataSource? local, RcpaRemoteDataSource? remote})
      : _local = local ?? RcpaLocalDataSource(),
        _remote = remote ?? RcpaRemoteDataSource();

  final RcpaLocalDataSource _local;
  final RcpaRemoteDataSource _remote;

  Future<void> logEntry(RcpaEntry entry) {
    debugPrint('RcpaRepository.logEntry: mrUid=${entry.mrUid} pharmacyId=${entry.pharmacyId}');
    return _local.insert(entry);
  }

  Future<List<RcpaEntry>> loadForMr(String mrUid) => _local.getForMr(mrUid);

  /// How many entries are queued locally, waiting to reach Firestore.
  Future<int> countPendingUpload() => _local.countUnsynced();

  Future<void> uploadPending() async {
    debugPrint('RcpaRepository.uploadPending: checking for unsynced entries');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('RcpaRepository.uploadPending: nothing to upload');
      return;
    }
    debugPrint('RcpaRepository.uploadPending: uploading ${pending.length} entries');
    await _remote.upload(pending);
    await _local.markSynced(pending.map((entry) => entry.id).toList());
    debugPrint('RcpaRepository.uploadPending: upload complete');
  }

  Future<List<RcpaEntry>> fetchRecentForDashboard() => _remote.fetchRecent();

  /// For a manager without global visibility — see
  /// [RcpaRemoteDataSource.fetchRecentForEmployees].
  Future<List<RcpaEntry>> fetchRecentForEmployees(List<String> mrUids) => _remote.fetchRecentForEmployees(mrUids);
}
