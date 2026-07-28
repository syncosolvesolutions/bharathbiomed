import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/sales_target.dart';
import '../auth/auth_controller.dart';
import '../team/team_access.dart';
import 'team_targets_controller.dart';

/// Set (or update) a monthly target for one of the signed-in user's
/// reporting-chain downline. [initialEmployee] preselects the employee when
/// reached from [TeamTargetsScreen]'s per-row "Set Target" action.
class SetTargetScreen extends ConsumerStatefulWidget {
  const SetTargetScreen({super.key, this.initialEmployee});

  final Employee? initialEmployee;

  @override
  ConsumerState<SetTargetScreen> createState() => _SetTargetScreenState();
}

class _SetTargetScreenState extends ConsumerState<SetTargetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _valueController = TextEditingController();
  Employee? _selectedEmployee;
  late String _period = currentTargetPeriod();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedEmployee = widget.initialEmployee;
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    setState(() => _period = currentTargetPeriod(picked));
  }

  Future<void> _save() async {
    if (_selectedEmployee == null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Employee required',
        text: 'Please select who this target is for.',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).value?.uid ?? '';
      await ref.read(salesTargetRepositoryProvider).setTarget(
            employeeUid: _selectedEmployee!.uid,
            period: _period,
            targetValue: double.parse(_valueController.text.trim()),
            createdByUid: uid,
          );
      ref.invalidate(teamTargetsControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Target set for ${_selectedEmployee!.displayName} — $_period.')),
      );
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.error('SetTarget', 'setTarget failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to set target',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(visibleEmployeesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Set Target')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              employeesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Failed to load employees: ${UserFacingError.describe(error)}'),
                data: (employees) {
                  if (employees.isEmpty) {
                    return const Text('Nobody reports to you yet.');
                  }
                  return DropdownButtonFormField<Employee>(
                    initialValue: _selectedEmployee,
                    decoration: const InputDecoration(labelText: 'Employee'),
                    items: employees
                        .map((employee) => DropdownMenuItem(value: employee, child: Text(employee.displayName)))
                        .toList(),
                    onChanged: (employee) => setState(() => _selectedEmployee = employee),
                  );
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickPeriod,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Month'),
                  child: Row(children: [
                    Expanded(child: Text(_period)),
                    const Icon(Icons.calendar_today_outlined, size: 18),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: const InputDecoration(labelText: 'Target Value'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a target value greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Target'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
