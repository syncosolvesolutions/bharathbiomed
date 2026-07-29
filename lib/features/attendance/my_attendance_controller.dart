import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../auth/auth_controller.dart';
import 'attendance_day.dart';

/// The signed-in MR's own derived attendance — the first MR-facing view of
/// their own usage-session history (previously admin/manager-only, 
/// usage sessions" gap). Reuses
/// [UsageSessionRepository.fetchRecentForEmployees] with just this MR's own
/// uid rather than adding a new repository method.
final myAttendanceControllerProvider =
    AsyncNotifierProvider<MyAttendanceController, List<AttendanceDay>>(MyAttendanceController.new);

class MyAttendanceController extends AsyncNotifier<List<AttendanceDay>> {
  @override
  Future<List<AttendanceDay>> build() async {
    final uid = ref.read(authControllerProvider).value?.uid;
    debugPrint('MyAttendanceController.build: uid=$uid');
    if (uid == null) return [];
    final sessions = await ref.read(usageSessionRepositoryProvider).fetchRecentForEmployees([uid]);
    return deriveAttendanceDays(sessions);
  }

  Future<void> refresh() async {
    debugPrint('MyAttendanceController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
