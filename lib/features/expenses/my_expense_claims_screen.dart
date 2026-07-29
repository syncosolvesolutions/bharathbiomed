import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/expense_claim.dart';
import 'my_expense_claims_controller.dart';

/// The signed-in MR's own filed expense claims and their live status.
/// Mirrors [MyOrdersScreen] — not-yet-uploaded (still-local) claims don't
/// show up here, see [MyExpenseClaimsController].
class MyExpenseClaimsScreen extends ConsumerWidget {
  const MyExpenseClaimsScreen({super.key});

  Color _statusColor(ExpenseClaimStatus status) => switch (status) {
        ExpenseClaimStatus.pending => Colors.orange,
        ExpenseClaimStatus.approved => Colors.green,
        ExpenseClaimStatus.rejected => Colors.red,
      };

  String _statusLabel(ExpenseClaimStatus status) => switch (status) {
        ExpenseClaimStatus.pending => 'Pending approval',
        ExpenseClaimStatus.approved => 'Approved',
        ExpenseClaimStatus.rejected => 'Rejected',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(myExpenseClaimsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Expense Claims')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myExpenseClaimsControllerProvider.notifier).refresh(),
        child: claimsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load claims: ${UserFacingError.describe(error)}')),
          data: (claims) {
            if (claims.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No expense claims yet.\nTap "File Claim" below.', textAlign: TextAlign.center)),
                ],
              );
            }
            return ListView.builder(
              itemCount: claims.length,
              itemBuilder: (context, index) {
                final claim = claims[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text('${claim.category.label} • ${claim.amount.toStringAsFixed(2)}'),
                    subtitle: Text('${claim.claimDate}${claim.description.isNotEmpty ? '\n${claim.description}' : ''}'
                        '${claim.rejectedReason?.isNotEmpty ?? false ? '\nReason: ${claim.rejectedReason}' : ''}'),
                    isThreeLine: claim.description.isNotEmpty || (claim.rejectedReason?.isNotEmpty ?? false),
                    trailing: Chip(
                      label:
                          Text(_statusLabel(claim.status), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: _statusColor(claim.status),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        icon: const Icon(Icons.add),
        label: const Text('File Claim'),
      ),
    );
  }
}
