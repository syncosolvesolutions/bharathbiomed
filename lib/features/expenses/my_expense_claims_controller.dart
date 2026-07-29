import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/expense_claim.dart';
import '../auth/auth_controller.dart';

/// The signed-in MR's own filed expense claims, live from Firestore (see
/// [ExpenseClaimRepository.fetchMine]) — connectivity-assumed, same
/// reasoning as [MyOrdersController]: a claim's live status only matters
/// once it's actually reached the server. Not-yet-uploaded claims (still in
/// the local queue) aren't shown here — see `SyncController`'s
/// pending-upload count for that instead.
final myExpenseClaimsControllerProvider =
    AsyncNotifierProvider<MyExpenseClaimsController, List<ExpenseClaim>>(MyExpenseClaimsController.new);

class MyExpenseClaimsController extends AsyncNotifier<List<ExpenseClaim>> {
  @override
  Future<List<ExpenseClaim>> build() async {
    final uid = ref.read(authControllerProvider).value?.uid;
    debugPrint('MyExpenseClaimsController.build: uid=$uid');
    if (uid == null) return [];
    return ref.read(expenseClaimRepositoryProvider).fetchMine(uid);
  }

  Future<void> refresh() async {
    debugPrint('MyExpenseClaimsController.refresh: refreshing');
    state = await AsyncValue.guard(build);
  }
}
