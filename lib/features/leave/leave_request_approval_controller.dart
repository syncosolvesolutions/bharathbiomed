import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/leave_request.dart';
import '../auth/auth_controller.dart';
import '../team/team_access.dart';

/// Leave requests still needing a decision — mirrors
/// [ExpenseClaimApprovalController] exactly.
final leaveRequestApprovalControllerProvider =
    AsyncNotifierProvider<LeaveRequestApprovalController, List<LeaveRequest>>(LeaveRequestApprovalController.new);

class LeaveRequestApprovalController extends AsyncNotifier<List<LeaveRequest>> {
  @override
  Future<List<LeaveRequest>> build() async {
    debugPrint('LeaveRequestApprovalController.build: resolving visible employees');
    final requests = ref.read(hasGlobalVisibilityProvider)
        ? await ref.read(leaveRequestRepositoryProvider).fetchAll()
        : await ref
            .read(leaveRequestRepositoryProvider)
            .fetchForEmployees((await resolveVisibleEmployees(ref)).map((e) => e.uid).toList());
    return requests.where((request) => request.status == LeaveRequestStatus.pending).toList();
  }

  Future<void> refresh() async {
    debugPrint('LeaveRequestApprovalController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }

  /// `approve_leave`-gated in firestore.rules.
  Future<void> approve(String requestId) async {
    debugPrint('LeaveRequestApprovalController.approve: requestId=$requestId');
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    await ref.read(leaveRequestRepositoryProvider).approve(requestId, approvedByUid: uid);
    await refresh();
  }

  /// `approve_leave`-gated in firestore.rules.
  Future<void> reject(String requestId, {String? reason}) async {
    debugPrint('LeaveRequestApprovalController.reject: requestId=$requestId');
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    await ref.read(leaveRequestRepositoryProvider).reject(requestId, approvedByUid: uid, reason: reason);
    await refresh();
  }
}
