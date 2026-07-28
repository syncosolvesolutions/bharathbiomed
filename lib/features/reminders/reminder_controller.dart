import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/reminder.dart';
import '../auth/auth_controller.dart';

/// This user's own reminders — for an MR, only ever reminders they created
/// for themselves; for the admin, their own reminders plus any they assigned
/// to an MR show up on that MR's list instead (see [Reminder.ownerUid]).
final myRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  final uid = ref.watch(authControllerProvider).value?.uid;
  debugPrint('myRemindersProvider: uid=$uid');
  if (uid == null) return const Stream<List<Reminder>>.empty();
  return ref.watch(reminderRepositoryProvider).watchFor(uid);
});
