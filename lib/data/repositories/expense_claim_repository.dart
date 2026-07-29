import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/expense_claim.dart';
import '../local/expense_claim_local_data_source.dart';
import '../remote/expense_claim_remote_data_source.dart';

/// An MR's filed expense claims, offline-first: [submit] only ever touches
/// the local queue (works standing in the field with no signal);
/// [uploadPending] is what the sync pipeline calls to actually reach
/// Firestore. Once uploaded, live status (approved/rejected) is only ever
/// read via [fetchMine]/[fetchAll]/[fetchForEmployees] — mirrors
/// [OrderRepository].
class ExpenseClaimRepository {
  ExpenseClaimRepository({ExpenseClaimRemoteDataSource? remote, ExpenseClaimLocalDataSource? local})
      : _remote = remote ?? ExpenseClaimRemoteDataSource(),
        _local = local ?? ExpenseClaimLocalDataSource();

  final ExpenseClaimRemoteDataSource _remote;
  final ExpenseClaimLocalDataSource _local;

  Future<void> submit(ExpenseClaim claim) async {
    debugPrint('ExpenseClaimRepository.submit: mrUid=${claim.mrUid} amount=${claim.amount}');
    final localId = const Uuid().v4();
    await _local.insert(localId, claim.toCreateJson());
    debugPrint('ExpenseClaimRepository.submit: queued localId=$localId');
  }

  Future<int> countPendingUpload() => _local.countUnsynced();

  /// Best-effort, called from the sync pipeline — never lets a partial
  /// failure lose already-queued claims (they just stay queued for the next
  /// sync attempt).
  Future<void> uploadPending() async {
    debugPrint('ExpenseClaimRepository.uploadPending: checking for unsynced claims');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('ExpenseClaimRepository.uploadPending: nothing to upload');
      return;
    }
    debugPrint('ExpenseClaimRepository.uploadPending: uploading ${pending.length} claims');
    final uploaded = <String>[];
    for (final claim in pending) {
      try {
        await _remote.create(claim.localId, claim.data);
        uploaded.add(claim.localId);
      } catch (error) {
        debugPrint('ExpenseClaimRepository.uploadPending: failed localId=${claim.localId} error=$error');
      }
    }
    await _local.markSynced(uploaded);
    debugPrint('ExpenseClaimRepository.uploadPending: uploaded ${uploaded.length}/${pending.length}');
  }

  Future<List<ExpenseClaim>> fetchMine(String mrUid) => _remote.fetchMine(mrUid);

  Future<List<ExpenseClaim>> fetchAll() => _remote.fetchAll();

  Future<List<ExpenseClaim>> fetchForEmployees(List<String> mrUids) => _remote.fetchForEmployees(mrUids);

  /// `approve_expenses`-gated in firestore.rules.
  Future<void> approve(String claimId, {required String approvedByUid}) =>
      _remote.approve(claimId, approvedByUid: approvedByUid);

  /// `approve_expenses`-gated in firestore.rules.
  Future<void> reject(String claimId, {required String approvedByUid, String? reason}) =>
      _remote.reject(claimId, approvedByUid: approvedByUid, reason: reason);
}
