import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../data/providers.dart';
import '../../domain/models/reminder.dart';
import 'reminder_controller.dart';
import 'reminder_form_dialog.dart';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatDueAt(DateTime dueAt) {
  final local = dueAt.toLocal();
  return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

/// Requirement 15/16: reminders list shared by both admin and MR — each just
/// sees their own (see [myRemindersProvider]).
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  Future<void> _toggleCompleted(BuildContext context, WidgetRef ref, Reminder reminder) async {
    try {
      await ref.read(reminderRepositoryProvider).setCompleted(reminder.id, !reminder.completed);
    } catch (error, stackTrace) {
      AppLogger.error('Reminders', 'setCompleted failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update: ${UserFacingError.describe(error)}')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Reminder reminder) async {
    try {
      await ref.read(reminderRepositoryProvider).delete(reminder.id);
    } catch (error, stackTrace) {
      AppLogger.error('Reminders', 'delete failed', error: error, stackTrace: stackTrace);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete: ${UserFacingError.describe(error)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(myRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load reminders: ${UserFacingError.describe(error)}')),
        data: (reminders) {
          if (reminders.isEmpty) {
            return const Center(child: Text('No reminders yet.\nTap + to add one.', textAlign: TextAlign.center));
          }
          return ListView.builder(
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              return ListTile(
                leading: Checkbox(
                  value: reminder.completed,
                  onChanged: (_) => _toggleCompleted(context, ref, reminder),
                ),
                title: Text(
                  reminder.title,
                  style: TextStyle(decoration: reminder.completed ? TextDecoration.lineThrough : null),
                ),
                subtitle: Text(
                  '${reminder.note.isNotEmpty ? '${reminder.note}\n' : ''}'
                  'Due ${_formatDueAt(reminder.dueAt)}${reminder.isOverdue ? ' • Overdue' : ''}',
                  style: reminder.isOverdue ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
                ),
                isThreeLine: reminder.note.isNotEmpty,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref, reminder),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddReminderDialog(context, ref),
        child: const Icon(Icons.add_alert_outlined),
      ),
    );
  }
}
