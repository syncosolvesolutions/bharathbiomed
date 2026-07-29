import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_batch.dart';
import 'admin_catalog_controller.dart';

/// Batch/expiry detail for one product — add a newly-received batch
/// (batch number, expiry date, quantity; adds onto
/// [Product.stockQuantity] in the same transaction, see
/// [AdminCatalogController.addBatch]), or remove one (e.g. an expired lot
/// written off). Batches expiring within 30 days are highlighted; already-
/// expired ones are flagged in red.
class ProductBatchesScreen extends ConsumerStatefulWidget {
  const ProductBatchesScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductBatchesScreen> createState() => _ProductBatchesScreenState();
}

class _ProductBatchesScreenState extends ConsumerState<ProductBatchesScreen> {
  Future<void> _addBatch() async {
    final batchNumberController = TextEditingController();
    final quantityController = TextEditingController();
    String expiryDate = isoFromDate(DateTime.now().add(const Duration(days: 365)));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Batch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: batchNumberController,
                decoration: const InputDecoration(labelText: 'Batch Number'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: dateFromIso(expiryDate) ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked == null) return;
                  setDialogState(() => expiryDate = isoFromDate(picked));
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Expiry Date'),
                  child: Text(formatIsoForDisplay(expiryDate)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity Received'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    final batchNumber = batchNumberController.text.trim();
    if (batchNumber.isEmpty || quantity <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Batch number and a positive quantity are required.')));
      return;
    }

    try {
      await ref
          .read(adminCatalogControllerProvider.notifier)
          .addBatch(widget.product.id, batchNumber: batchNumber, expiryDate: expiryDate, quantity: quantity);
      ref.invalidate(productBatchesProvider(widget.product.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch added.')));
    } catch (error, stackTrace) {
      AppLogger.error('ProductBatches', 'addBatch failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  Future<void> _deleteBatch(ProductBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete batch ${batch.batchNumber}?'),
        content: Text('This removes ${batch.quantity} units from stock along with the batch record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(adminCatalogControllerProvider.notifier).deleteBatch(widget.product.id, batch.id);
      ref.invalidate(productBatchesProvider(widget.product.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch deleted.')));
    } catch (error, stackTrace) {
      AppLogger.error('ProductBatches', 'deleteBatch failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(productBatchesProvider(widget.product.id));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.product.name} — Batches')),
      body: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load batches: ${UserFacingError.describe(error)}')),
        data: (batches) {
          final batchTotal = batches.fold<int>(0, (sum, b) => sum + b.quantity);
          final mismatch = batchTotal != widget.product.stockQuantity;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total stock: ${widget.product.stockQuantity}'),
                    Text('Tracked in batches: $batchTotal'),
                    if (mismatch)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Batch total doesn\'t match stock — some stock was added/adjusted outside batch '
                          'tracking (e.g. via "Adjust Stock"). This is expected if batches aren\'t used for '
                          'every stock movement.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: batches.isEmpty
                    ? const Center(child: Text('No batches tracked yet.'))
                    : ListView.builder(
                        itemCount: batches.length,
                        itemBuilder: (context, index) {
                          final batch = batches[index];
                          final expiry = dateFromIso(batch.expiryDate);
                          final daysLeft = expiry?.difference(DateTime.now()).inDays;
                          final expired = batch.isExpired;
                          final expiringSoon = !expired && daysLeft != null && daysLeft <= 30;
                          final color = expired
                              ? Theme.of(context).colorScheme.error
                              : expiringSoon
                                  ? Colors.orange
                                  : null;
                          return ListTile(
                            leading: Icon(
                              expired ? Icons.error_outline : Icons.inventory_2_outlined,
                              color: color,
                            ),
                            title: Text('Batch ${batch.batchNumber}'),
                            subtitle: Text(
                              'Qty: ${batch.quantity} • Expires: ${formatIsoForDisplay(batch.expiryDate)}'
                              '${expired ? ' (expired)' : expiringSoon ? ' (expiring soon)' : ''}',
                              style: color != null ? TextStyle(color: color, fontWeight: FontWeight.w600) : null,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteBatch(batch),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBatch,
        icon: const Icon(Icons.add),
        label: const Text('Add Batch'),
      ),
    );
  }
}
