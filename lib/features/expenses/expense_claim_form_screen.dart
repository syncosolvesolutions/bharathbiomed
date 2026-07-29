import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../data/providers.dart';
import '../../domain/models/expense_claim.dart';
import '../admin/widgets/photo_picker_field.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_controller.dart';
import 'my_expense_claims_controller.dart';

/// File a TA/DA expense claim: category, date, amount, optional description
/// and receipt photo. Offline-first for everything except the receipt photo
/// — see [ExpenseClaim]'s doc comment for why — [_save] queues the claim
/// locally either way; it reaches Firestore on the next sync.
class ExpenseClaimFormScreen extends ConsumerStatefulWidget {
  const ExpenseClaimFormScreen({super.key});

  @override
  ConsumerState<ExpenseClaimFormScreen> createState() => _ExpenseClaimFormScreenState();
}

class _ExpenseClaimFormScreenState extends ConsumerState<ExpenseClaimFormScreen> {
  ExpenseCategory _category = ExpenseCategory.travel;
  String _claimDate = isoFromDate(DateTime.now());
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _receiptPhotoUrl;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFromIso(_claimDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _claimDate = isoFromDate(picked));
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Invalid amount',
        text: 'Enter an amount greater than 0.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).value?.uid ?? '';
      final myName = ref.read(myEmployeeProfileProvider).value?.displayName ?? '';
      final claim = ExpenseClaim(
        id: const Uuid().v4(),
        mrUid: uid,
        mrName: myName,
        category: _category,
        claimDate: _claimDate,
        amount: amount,
        description: _descriptionController.text.trim(),
        receiptPhotoUrl: _receiptPhotoUrl,
      );
      await ref.read(expenseClaimRepositoryProvider).submit(claim);
      ref.invalidate(myExpenseClaimsControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expense claim queued — will upload on next sync.')));
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.error('ExpenseClaimForm', 'save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to save claim',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('File Expense Claim')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ExpenseCategory.values
                  .map((category) => DropdownMenuItem(value: category, child: Text(category.label)))
                  .toList(),
              onChanged: (category) => setState(() => _category = category ?? _category),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Claim Date'),
                child: Row(children: [
                  Expanded(child: Text(formatIsoForDisplay(_claimDate))),
                  const Icon(Icons.calendar_today_outlined, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Requires connectivity — see this screen's doc comment. Skipping
            // this is fine: the claim itself still queues and syncs offline.
            PhotoPickerField(
              folder: 'expense_receipts',
              label: 'Attach Receipt Photo (optional, needs connectivity)',
              onUploaded: (url) => setState(() => _receiptPhotoUrl = url),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Claim'),
            ),
          ],
        ),
      ),
    );
  }
}
