import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/sales_target.dart';
import '../auth/auth_controller.dart';
import 'target_progress.dart';

/// The signed-in user's own current-month target vs. achievement — live
/// (connectivity-assumed, same reasoning as [InvoiceRepository]).
final myTargetControllerProvider = AsyncNotifierProvider<MyTargetController, TargetProgress>(MyTargetController.new);

class MyTargetController extends AsyncNotifier<TargetProgress> {
  @override
  Future<TargetProgress> build() async {
    final uid = ref.read(authControllerProvider).value?.uid;
    final period = currentTargetPeriod();
    debugPrint('MyTargetController.build: uid=$uid period=$period');
    if (uid == null) return TargetProgress(period: period, achievement: 0);

    final target = await ref.read(salesTargetRepositoryProvider).fetchForEmployee(uid, period);
    final orders = await ref.read(orderRepositoryProvider).fetchMine(uid);
    final achievement = achievementForPeriod(orders, period);

    return TargetProgress(period: period, target: target, achievement: achievement);
  }

  Future<void> refresh() async {
    debugPrint('MyTargetController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
