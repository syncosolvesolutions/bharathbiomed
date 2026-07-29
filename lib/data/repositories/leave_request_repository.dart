import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/leave_request.dart';
import '../local/leave_request_local_data_source.dart';
import '../remote/leave_request_remote_data_source.dart';

/// An MR's filed leave requests, offline-first: [submit] only ever touches
/// the local queue; [uploadPending] is what the sync pipeline calls to
/// actually reach Firestore. Mirrors [ExpenseClaimRepository] exactly.
class LeaveRequestRepository {
  LeaveRequestRepository({LeaveRequestRemoteDataSource? remote, LeaveRequestLocalDataSource? local})
      : _remote = remote ?? LeaveRequestRemoteDataSource(),
        _local = local ?? LeaveRequestLocalDataSource();

  final LeaveRequestRemoteDataSource _remote;
  final LeaveRequestLocalDataSource _local;

  Future<void> submit(LeaveRequest request) async {
    debugPrint('LeaveRequestRepository.submit: mrUid=${request.mrUid} ${request.startDate}..${request.endDate}');
    final localId = const Uuid().v4();
    await _local.insert(localId, request.toCreateJson());
    debugPrint('LeaveRequestRepository.submit: queued localId=$localId');
  }

  Future<int> countPendingUpload() => _local.countUnsynced();

  /// Best-effort, called from the sync pipeline — never lets a partial
  /// failure lose already-queued requests (they just stay queued for the
  /// next sync attempt).
  Future<void> uploadPending() async {
    debugPrint('LeaveRequestRepository.uploadPending: checking for unsynced requests');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('LeaveRequestRepository.uploadPending: nothing to upload');
      return;
    }
    debugPrint('LeaveRequestRepository.uploadPending: uploading ${pending.length} requests');
    final uploaded = <String>[];
    for (final request in pending) {
      try {
        await _remote.create(request.localId, request.data);
        uploaded.add(request.localId);
      } catch (error) {
        debugPrint('LeaveRequestRepository.uploadPending: failed localId=${request.localId} error=$error');
      }
    }
    await _local.markSynced(uploaded);
    debugPrint('LeaveRequestRepository.uploadPending: uploaded ${uploaded.length}/${pending.length}');
  }

  Future<List<LeaveRequest>> fetchMine(String mrUid) => _remote.fetchMine(mrUid);

  Future<List<LeaveRequest>> fetchAll() => _remote.fetchAll();

  Future<List<LeaveRequest>> fetchForEmployees(List<String> mrUids) => _remote.fetchForEmployees(mrUids);

  /// `approve_leave`-gated in firestore.rules.
  Future<void> approve(String requestId, {required String approvedByUid}) =>
      _remote.approve(requestId, approvedByUid: approvedByUid);

  /// `approve_leave`-gated in firestore.rules.
  Future<void> reject(String requestId, {required String approvedByUid, String? reason}) =>
      _remote.reject(requestId, approvedByUid: approvedByUid, reason: reason);
}
