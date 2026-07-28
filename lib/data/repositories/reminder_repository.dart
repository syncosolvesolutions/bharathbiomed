import '../../domain/models/reminder.dart';
import '../remote/reminder_remote_data_source.dart';

/// Reminders (requirement 15/16) are created/read directly against
/// Firestore rather than offline-first: unlike doctor visits, creating a
/// reminder isn't something that happens standing in a hospital with no
/// signal — it's forward planning, normally done with connectivity.
class ReminderRepository {
  ReminderRepository({ReminderRemoteDataSource? remote}) : _remote = remote ?? ReminderRemoteDataSource();

  final ReminderRemoteDataSource _remote;

  Stream<List<Reminder>> watchFor(String ownerUid) => _remote.watchFor(ownerUid);

  Future<void> create(Reminder reminder) => _remote.create(reminder);

  Future<void> setCompleted(String id, bool completed) => _remote.setCompleted(id, completed);

  Future<void> delete(String id) => _remote.delete(id);
}
