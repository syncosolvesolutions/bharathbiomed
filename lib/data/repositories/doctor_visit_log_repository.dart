import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/doctor_visit_log.dart';
import '../local/doctor_visit_log_local_data_source.dart';
import '../remote/doctor_visit_log_remote_data_source.dart';

/// Daily doctor visit/feedback logs — offline-first, mirrors
/// [UsageSessionRepository]: [logVisit] only ever writes locally (requirement
/// 7/11), [uploadPending] is what the evening sync calls to reach Firestore.
class DoctorVisitLogRepository {
  DoctorVisitLogRepository({DoctorVisitLogLocalDataSource? local, DoctorVisitLogRemoteDataSource? remote})
      : _local = local ?? DoctorVisitLogLocalDataSource(),
        _remote = remote ?? DoctorVisitLogRemoteDataSource();

  final DoctorVisitLogLocalDataSource _local;
  final DoctorVisitLogRemoteDataSource _remote;

  Future<void> logVisit({
    required String mrUid,
    required String doctorId,
    required String doctorName,
    required String visitDate,
    required bool visited,
    required String feedback,
    double? latitude,
    double? longitude,
    Map<String, int> samplesGiven = const {},
  }) async {
    debugPrint('DoctorVisitLogRepository.logVisit: mrUid=$mrUid doctorId=$doctorId visitDate=$visitDate');
    await _local.insert(DoctorVisitLog(
      id: const Uuid().v4(),
      mrUid: mrUid,
      doctorId: doctorId,
      doctorName: doctorName,
      visitDate: visitDate,
      visited: visited,
      feedback: feedback,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
      samplesGiven: samplesGiven,
    ));
  }

  Future<List<DoctorVisitLog>> loadForMr(String mrUid) => _local.getForMr(mrUid);

  /// How many visit logs are queued locally, waiting to reach Firestore —
  /// used by the sync prompt to know there's something to push.
  Future<int> countPendingUpload() async => (await _local.getUnsynced()).length;

  Future<void> uploadPending() async {
    debugPrint('DoctorVisitLogRepository.uploadPending: checking for unsynced logs');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('DoctorVisitLogRepository.uploadPending: nothing to upload');
      return;
    }
    debugPrint('DoctorVisitLogRepository.uploadPending: uploading ${pending.length} logs');
    await _remote.upload(pending);
    await _local.markSynced(pending.map((log) => log.id).toList());
    debugPrint('DoctorVisitLogRepository.uploadPending: upload complete');
  }

  Future<List<DoctorVisitLog>> fetchRecentForDashboard() => _remote.fetchRecent();

  /// For a manager without global visibility — see
  /// [DoctorVisitLogRemoteDataSource.fetchRecentForEmployees].
  Future<List<DoctorVisitLog>> fetchRecentForEmployees(List<String> mrUids) => _remote.fetchRecentForEmployees(mrUids);
}
