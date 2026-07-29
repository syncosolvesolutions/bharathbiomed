import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../data/providers.dart';
import '../../domain/models/compliance_log.dart';
import '../../domain/models/doctor.dart';
import '../auth/auth_controller.dart';
import '../doctors/doctor_controller.dart';
import '../profile/profile_controller.dart';
import 'my_compliance_logs_controller.dart';

/// Log a UCPMP compliance record: which doctor, what was given, its value,
/// optional description. Offline-first — [_save] only ever queues locally;
/// it reaches Firestore on the next sync. See [ComplianceLog]'s doc
/// comment for why this exists and what it's not (a way to justify
/// spending, or a hard spending cap).
class ComplianceLogFormScreen extends ConsumerStatefulWidget {
  const ComplianceLogFormScreen({super.key});

  @override
  ConsumerState<ComplianceLogFormScreen> createState() => _ComplianceLogFormScreenState();
}

class _ComplianceLogFormScreenState extends ConsumerState<ComplianceLogFormScreen> {
  Doctor? _selectedDoctor;
  ComplianceCategory _category = ComplianceCategory.sample;
  String _logDate = isoFromDate(DateTime.now());
  final _descriptionController = TextEditingController();
  final _valueController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFromIso(_logDate) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _logDate = isoFromDate(picked));
  }

  Future<void> _save() async {
    if (_selectedDoctor == null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Doctor required',
        text: 'Please select which doctor this was given to.',
      );
      return;
    }
    final value = double.tryParse(_valueController.text.trim());
    if (value == null || value < 0) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Invalid value',
        text: 'Enter a value of 0 or more.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).value?.uid ?? '';
      final myName = ref.read(myEmployeeProfileProvider).value?.displayName ?? '';
      final log = ComplianceLog(
        id: const Uuid().v4(),
        mrUid: uid,
        mrName: myName,
        doctorId: _selectedDoctor!.id,
        doctorName: _selectedDoctor!.name,
        category: _category,
        description: _descriptionController.text.trim(),
        value: value,
        logDate: _logDate,
        createdAt: DateTime.now(),
      );
      await ref.read(complianceLogRepositoryProvider).logEntry(log);
      ref.invalidate(myComplianceLogsControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Compliance entry queued — will upload on next sync.')));
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.error('ComplianceLogForm', 'save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to save entry',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(doctorControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Compliance Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            doctorsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Failed to load doctors: ${UserFacingError.describe(error)}'),
              data: (doctors) => DropdownButtonFormField<Doctor>(
                initialValue: _selectedDoctor,
                decoration: const InputDecoration(labelText: 'Doctor'),
                items: doctors.map((doctor) => DropdownMenuItem(value: doctor, child: Text(doctor.name))).toList(),
                onChanged: (doctor) => setState(() => _selectedDoctor = doctor),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ComplianceCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: ComplianceCategory.values
                  .map((category) => DropdownMenuItem(value: category, child: Text(category.label)))
                  .toList(),
              onChanged: (category) => setState(() => _category = category ?? _category),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Row(children: [
                  Expanded(child: Text(formatIsoForDisplay(_logDate))),
                  const Icon(Icons.calendar_today_outlined, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(labelText: 'Value'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
