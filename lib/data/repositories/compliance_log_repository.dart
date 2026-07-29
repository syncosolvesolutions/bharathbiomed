import 'package:flutter/foundation.dart';

import '../../domain/models/compliance_log.dart';
import '../local/compliance_log_local_data_source.dart';
import '../remote/compliance_log_remote_data_source.dart';

/// Compliance logs, offline-first — mirrors [RcpaRepository] exactly.
class ComplianceLogRepository {
  ComplianceLogRepository({ComplianceLogLocalDataSource? local, ComplianceLogRemoteDataSource? remote})
      : _local = local ?? ComplianceLogLocalDataSource(),
        _remote = remote ?? ComplianceLogRemoteDataSource();

  final ComplianceLogLocalDataSource _local;
  final ComplianceLogRemoteDataSource _remote;

  Future<void> logEntry(ComplianceLog log) {
    debugPrint('ComplianceLogRepository.logEntry: mrUid=${log.mrUid} doctorId=${log.doctorId}');
    return _local.insert(log);
  }

  Future<List<ComplianceLog>> loadForMr(String mrUid) => _local.getForMr(mrUid);

  Future<int> countPendingUpload() => _local.countUnsynced();

  Future<void> uploadPending() async {
    debugPrint('ComplianceLogRepository.uploadPending: checking for unsynced logs');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('ComplianceLogRepository.uploadPending: nothing to upload');
      return;
    }
    debugPrint('ComplianceLogRepository.uploadPending: uploading ${pending.length} logs');
    await _remote.upload(pending);
    await _local.markSynced(pending.map((log) => log.id).toList());
    debugPrint('ComplianceLogRepository.uploadPending: upload complete');
  }

  Future<List<ComplianceLog>> fetchRecentForDashboard() => _remote.fetchRecent();

  Future<List<ComplianceLog>> fetchRecentForEmployees(List<String> mrUids) => _remote.fetchRecentForEmployees(mrUids);
}
