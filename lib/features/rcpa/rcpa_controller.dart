import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/rcpa_entry.dart';
import '../auth/auth_controller.dart';

/// The signed-in MR's own RCPA entries — offline-first, reads the local
/// queue directly (synced or not), mirrors how `today_visits_screen.dart`
/// reads `DoctorVisitLogRepository.loadForMr`.
final myRcpaEntriesControllerProvider =
    AsyncNotifierProvider<MyRcpaEntriesController, List<RcpaEntry>>(MyRcpaEntriesController.new);

class MyRcpaEntriesController extends AsyncNotifier<List<RcpaEntry>> {
  @override
  Future<List<RcpaEntry>> build() async {
    final uid = ref.read(authControllerProvider).value?.uid;
    debugPrint('MyRcpaEntriesController.build: uid=$uid');
    if (uid == null) return [];
    final entries = await ref.read(rcpaRepositoryProvider).loadForMr(uid);
    return entries..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> refresh() async {
    debugPrint('MyRcpaEntriesController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
