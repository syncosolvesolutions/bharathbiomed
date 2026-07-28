import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import '../admin/usage_format.dart';
import 'invoice_controller.dart';

/// Every generated invoice — see [InvoicesController].
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
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
                return ListTile(
                  title: Text('Invoice ${invoice.invoiceNumber}'),
                  subtitle: Text(
                    '${invoice.agencyName} • ${invoice.items.length} product${invoice.items.length == 1 ? '' : 's'}'
                    '${invoice.issuedAt == null ? '' : '\n${formatDateTime(invoice.issuedAt!)}'}',
                  ),
                  isThreeLine: invoice.issuedAt != null,
                  trailing: Text(invoice.totalValue.toStringAsFixed(2)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
