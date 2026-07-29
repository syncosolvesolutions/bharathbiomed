import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/expense_claim.dart';
import '../auth/auth_controller.dart';
import '../team/team_access.dart';

/// Expense claims still needing a decision (pending only — approved/
/// rejected are terminal) — everyone's for a [hasGlobalVisibilityProvider]
/// holder, just the signed-in user's own reporting-chain downline
/// otherwise (see [resolveVisibleEmployees]). Mirrors
/// [OrderApprovalController]; fetches unfiltered-by-status and filters
/// client-side for the same reason (Firestore only allows one
/// `whereIn`/equality filter per query and the uid-scoping already uses
/// it).
final expenseClaimApprovalControllerProvider =
    AsyncNotifierProvider<ExpenseClaimApprovalController, List<ExpenseClaim>>(ExpenseClaimApprovalController.new);

class ExpenseClaimApprovalController extends AsyncNotifier<List<ExpenseClaim>> {
  @override
  Future<List<ExpenseClaim>> build() async {
    debugPrint('ExpenseClaimApprovalController.build: resolving visible employees');
    final claims = ref.read(hasGlobalVisibilityProvider)
        ? await ref.read(expenseClaimRepositoryProvider).fetchAll()
        : await ref
            .read(expenseClaimRepositoryProvider)
            .fetchForEmployees((await resolveVisibleEmployees(ref)).map((e) => e.uid).toList());
    return claims.where((claim) => claim.status == ExpenseClaimStatus.pending).toList();
  }

  Future<void> refresh() async {
    debugPrint('ExpenseClaimApprovalController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }

  /// `approve_expenses`-gated in firestore.rules.
  Future<void> approve(String claimId) async {
    debugPrint('ExpenseClaimApprovalController.approve: claimId=$claimId');
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    await ref.read(expenseClaimRepositoryProvider).approve(claimId, approvedByUid: uid);
    await refresh();
  }

  /// `approve_expenses`-gated in firestore.rules.
  Future<void> reject(String claimId, {String? reason}) async {
    debugPrint('ExpenseClaimApprovalController.reject: claimId=$claimId');
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    await ref.read(expenseClaimRepositoryProvider).reject(claimId, approvedByUid: uid, reason: reason);
    await refresh();
  }
}
