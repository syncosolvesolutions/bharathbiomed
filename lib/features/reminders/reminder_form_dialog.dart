import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../data/providers.dart';
import '../../domain/models/employee.dart';
import '../../domain/models/reminder.dart';
import '../admin/admin_access.dart';
import '../admin/employee_controller.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_controller.dart';

/// Requirement 15/16: reminders for both admin and MR. The admin may create
/// a reminder for themselves or assign one to an MR; an MR can only ever
/// create one for themselves.
Future<void> showAddReminderDialog(BuildContext context, WidgetRef ref) async {
  final isAdmin = ref.read(isAdminProvider);
  final titleController = TextEditingController();
  final noteController = TextEditingController();
  DateTime dueAt = DateTime.now().add(const Duration(hours: 1));
  Employee? assignedTo; // null means "myself"
  bool saving = false;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        Future<void> pickDueDateTime() async {
          final date = await showDatePicker(
            context: context,
            initialDate: dueAt,
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          );
          if (date == null || !context.mounted) return;
          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dueAt));
          if (time == null) return;
          setState(() => dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
        }

        Future<void> save() async {
          if (titleController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title.')));
            return;
          }
          setState(() => saving = true);
          try {
            final myUid = ref.read(authControllerProvider).value?.uid ?? '';
            final myName = isAdmin ? 'Admin' : (ref.read(myEmployeeProfileProvider).value?.displayName ?? '');
            final ownerUid = assignedTo?.uid ?? myUid;
            final ownerName = assignedTo?.displayName ?? myName;
            await ref.read(reminderRepositoryProvider).create(Reminder(
                  id: '',
                  ownerUid: ownerUid,
                  ownerName: ownerName,
                  createdByUid: myUid,
                  createdByName: myName,
                  title: titleController.text.trim(),
                  note: noteController.text.trim(),
                  dueAt: dueAt,
                ));
            if (!context.mounted) return;
            Navigator.of(context).pop();
          } catch (error, stackTrace) {
            AppLogger.error('ReminderForm', 'create failed', error: error, stackTrace: stackTrace);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Failed to save reminder: ${UserFacingError.describe(error)}')));
          } finally {
            if (context.mounted) setState(() => saving = false);
          }
        }

        final employeesAsync = isAdmin ? ref.watch(employeeControllerProvider) : null;

        return AlertDialog(
          title: const Text('New Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  enabled: !saving,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                  maxLines: 2,
                  enabled: !saving,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: saving ? null : pickDueDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Due'),
                    child: Text('${dueAt.toLocal()}'.substring(0, 16)),
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  employeesAsync!.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Failed to load MRs: ${UserFacingError.describe(error)}'),
                    data: (employees) => DropdownButtonFormField<Employee?>(
                      initialValue: assignedTo,
                      decoration: const InputDecoration(labelText: 'For'),
                      items: [
                        const DropdownMenuItem<Employee?>(value: null, child: Text('Myself')),
                        ...employees.map((e) => DropdownMenuItem<Employee?>(value: e, child: Text(e.displayName))),
                      ],
                      onChanged: saving ? null : (value) => setState(() => assignedTo = value),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        );
      });
    },
  );
}
