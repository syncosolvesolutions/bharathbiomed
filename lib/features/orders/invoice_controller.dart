import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/invoice.dart';

/// Every generated invoice, live from Firestore — read access is gated by
/// `manage_invoices`/`view_global_data`/admin in firestore.rules, mirrored
/// client-side by only showing the nav entry point to those same holders
/// (see `hasPermissionProvider`/`hasGlobalVisibilityProvider`).
final invoicesControllerProvider = AsyncNotifierProvider<InvoicesController, List<Invoice>>(InvoicesController.new);

class InvoicesController extends AsyncNotifier<List<Invoice>> {
  @override
  Future<List<Invoice>> build() {
    debugPrint('InvoicesController.build: fetching invoices');
    return ref.read(invoiceRepositoryProvider).fetchAll();
  }

  Future<void> refresh() async {
    debugPrint('InvoicesController.refresh: refreshing');
    state = await AsyncValue.guard(() => ref.read(invoiceRepositoryProvider).fetchAll());
  }
}
