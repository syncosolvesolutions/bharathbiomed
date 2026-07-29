import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/report_export_service.dart';
import '../../core/widgets/export_menu_button.dart';
import '../../data/providers.dart';
import '../../domain/models/invoice.dart';
import '../../domain/models/permission.dart';
import '../admin/usage_format.dart';
import '../team/team_access.dart';
import 'invoice_controller.dart';

/// Every generated invoice — see [InvoicesController]. Whoever holds
/// `manage_invoices` can also record a payment against one, updating its
/// [PaymentStatus] (see [_recordPayment]).
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  Color _statusColor(Invoice invoice) {
    if (invoice.isOverdue) return Colors.red;
    return switch (invoice.paymentStatus) {
      PaymentStatus.unpaid => Colors.orange,
      PaymentStatus.partial => Colors.blue,
      PaymentStatus.paid => Colors.green,
    };
  }

  String _statusLabel(Invoice invoice) {
    if (invoice.isOverdue) return 'Overdue';
    return switch (invoice.paymentStatus) {
      PaymentStatus.unpaid => 'Unpaid',
      PaymentStatus.partial => 'Partially Paid',
      PaymentStatus.paid => 'Paid',
    };
  }

  Future<void> _recordPayment(BuildContext context, WidgetRef ref, Invoice invoice) async {
    final amountController = TextEditingController(text: invoice.balanceDue.toStringAsFixed(2));
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record payment — ${invoice.invoiceNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Balance due: ${invoice.balanceDue.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount received'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record')),
        ],
      ),
    );
    if (confirmed != true) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount greater than 0.')));
      return;
    }

    try {
      await ref.read(invoiceRepositoryProvider).recordPayment(
            invoice.id,
            amount: amount,
            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          );
      ref.invalidate(invoicesControllerProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded.')));
    } catch (error, stackTrace) {
      AppLogger.error('InvoicesScreen', 'recordPayment failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: ${UserFacingError.describe(error)}')));
    }
  }

  List<List<String>> _rows(List<Invoice> invoices) => invoices
      .map((invoice) => [
            invoice.invoiceNumber,
            invoice.agencyName,
            invoice.totalValue.toStringAsFixed(2),
            invoice.taxAmount.toStringAsFixed(2),
            invoice.grandTotal.toStringAsFixed(2),
            invoice.amountPaid.toStringAsFixed(2),
            _statusLabel(invoice),
            invoice.issuedAt == null ? '' : formatDateTime(invoice.issuedAt!),
          ])
      .toList();

  Future<void> _exportCsv(WidgetRef ref, List<Invoice> invoices) {
    return ref.read(reportExportServiceProvider).exportCsv(
          filename: 'invoices.csv',
          headers: const [
            'Invoice #',
            'Agency',
            'Subtotal',
            'Tax',
            'Grand Total',
            'Amount Paid',
            'Status',
            'Issued',
          ],
          rows: _rows(invoices),
        );
  }

  Future<void> _exportPdf(WidgetRef ref, List<Invoice> invoices) {
    return ref.read(reportExportServiceProvider).exportSimpleTablePdf(
          filename: 'invoices.pdf',
          title: 'Invoices',
          headers: const ['Invoice #', 'Agency', 'Subtotal', 'Tax', 'Grand Total', 'Paid', 'Status'],
          rows: invoices
              .map((invoice) => [
                    invoice.invoiceNumber,
                    invoice.agencyName,
                    invoice.totalValue.toStringAsFixed(2),
                    invoice.taxAmount.toStringAsFixed(2),
                    invoice.grandTotal.toStringAsFixed(2),
                    invoice.amountPaid.toStringAsFixed(2),
                    _statusLabel(invoice),
                  ])
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesControllerProvider);
    final canManageInvoices = ref.watch(hasPermissionProvider(Permission.manageInvoices));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          if (invoicesAsync.value != null)
            ExportMenuButton(
              onExportCsv: () => _exportCsv(ref, invoicesAsync.value!),
              onExportPdf: () => _exportPdf(ref, invoicesAsync.value!),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(invoicesControllerProvider.notifier).refresh(),
        child: invoicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load invoices: ${UserFacingError.describe(error)}')),
          data: (invoices) {
            if (invoices.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No invoices generated yet.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('Invoice ${invoice.invoiceNumber}',
                                  style: Theme.of(context).textTheme.titleMedium),
                            ),
                            Chip(
                              label: Text(_statusLabel(invoice),
                                  style: const TextStyle(color: Colors.white, fontSize: 12)),
                              backgroundColor: _statusColor(invoice),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${invoice.agencyName} • ${invoice.items.length} product${invoice.items.length == 1 ? '' : 's'}'
                          '${invoice.issuedAt == null ? '' : '\nIssued: ${formatDateTime(invoice.issuedAt!)}'}',
                        ),
                        const SizedBox(height: 8),
                        Text('Subtotal: ${invoice.totalValue.toStringAsFixed(2)}'),
                        if (invoice.taxAmount > 0)
                          Text('${invoice.taxLabel} (${invoice.taxRate.toStringAsFixed(1)}%): '
                              '${invoice.taxAmount.toStringAsFixed(2)}'),
                        Text('Grand total: ${invoice.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (invoice.paymentStatus != PaymentStatus.unpaid)
                          Text('Paid so far: ${invoice.amountPaid.toStringAsFixed(2)}'),
                        if (invoice.paymentStatus != PaymentStatus.paid)
                          Text('Balance due: ${invoice.balanceDue.toStringAsFixed(2)}'),
                        if (canManageInvoices && invoice.paymentStatus != PaymentStatus.paid)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _recordPayment(context, ref, invoice),
                              child: const Text('Record Payment'),
                            ),
                          ),
                      ],
                    ),
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
