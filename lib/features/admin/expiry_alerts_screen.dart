import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import 'admin_catalog_controller.dart';

/// Every batch across every product expiring within 90 days, most-urgent
/// first — see [expiringBatchesProvider] (a `collectionGroup` query, not a
/// per-product fetch). Read-only: manage/delete a specific batch from that
/// product's own [ProductBatchesScreen] instead.
class ExpiryAlertsScreen extends ConsumerWidget {
  const ExpiryAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(expiringBatchesProvider);
    // Product names for display — the batch itself only carries a
    // productId (see ProductBatch), same join pattern as
    // VisitPlanApprovalScreen resolving mrUid -> Employee.
    final productNames = ref.watch(adminCatalogControllerProvider).maybeWhen(
          data: (snapshot) => {for (final p in snapshot.products) p.id: p.name},
          orElse: () => const <String, String>{},
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Expiry Alerts')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(expiringBatchesProvider),
        child: batchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load: ${UserFacingError.describe(error)}')),
          data: (batches) {
            if (batches.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nothing expiring in the next 90 days.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: batches.length,
              itemBuilder: (context, index) {
                final batch = batches[index];
                final expired = batch.isExpired;
                final color = expired ? Theme.of(context).colorScheme.error : Colors.orange;
                final productName = productNames[batch.productId] ?? batch.productId;
                return ListTile(
                  leading: Icon(expired ? Icons.error_outline : Icons.warning_amber_outlined, color: color),
                  title: Text('$productName — Batch ${batch.batchNumber}'),
                  subtitle: Text(
                    'Qty: ${batch.quantity} • Expires: ${formatIsoForDisplay(batch.expiryDate)}'
                    '${expired ? ' (expired)' : ''}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
