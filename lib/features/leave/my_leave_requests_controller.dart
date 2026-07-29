import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/leave_request.dart';
import '../auth/auth_controller.dart';

/// The signed-in MR's own filed leave requests, live from Firestore.
/// Mirrors [MyExpenseClaimsController] exactly.
final myLeaveRequestsControllerProvider =
    AsyncNotifierProvider<MyLeaveRequestsController, List<LeaveRequest>>(MyLeaveRequestsController.new);

class MyLeaveRequestsController extends AsyncNotifier<List<LeaveRequest>> {
  @override
  Future<List<LeaveRequest>> build() async {
    final uid = ref.read(authControllerProvider).value?.uid;
    debugPrint('MyLeaveRequestsController.build: uid=$uid');
    if (uid == null) return [];
    return ref.read(leaveRequestRepositoryProvider).fetchMine(uid);
  }

  Future<void> refresh() async {
    debugPrint('MyLeaveRequestsController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
