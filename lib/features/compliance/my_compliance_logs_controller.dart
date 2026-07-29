import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/compliance_log.dart';
import '../auth/auth_controller.dart';

/// The signed-in MR's own compliance logs — offline-first, reads the local
/// queue directly (synced or not). Mirrors [MyRcpaEntriesController].
final myComplianceLogsControllerProvider =
    AsyncNotifierProvider<MyComplianceLogsController, List<ComplianceLog>>(MyComplianceLogsController.new);

class MyComplianceLogsController extends AsyncNotifier<List<ComplianceLog>> {
  @override
  Future<List<ComplianceLog>> build() async {
    final uid = ref.read(authControllerProvider).value?.uid;
    debugPrint('MyComplianceLogsController.build: uid=$uid');
    if (uid == null) return [];
    final logs = await ref.read(complianceLogRepositoryProvider).loadForMr(uid);
    return logs..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> refresh() async {
    debugPrint('MyComplianceLogsController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
