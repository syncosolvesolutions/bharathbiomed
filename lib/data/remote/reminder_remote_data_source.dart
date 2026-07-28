import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/reminder.dart';

/// `Reminders`: written directly by the client (admin creating one for
/// themselves or an MR, or an MR creating one for themselves) — see
/// firestore.rules for who may set which `ownerUid`. Due-reminder pushes are
/// sent by the `sendDueReminders` scheduled Cloud Function, not from here.
class ReminderRemoteDataSource {
  ReminderRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Reminder>> watchFor(String ownerUid) {
    debugPrint('ReminderRemoteDataSource.watchFor: ownerUid=$ownerUid');
    return _firestore.collection('Reminders').where('ownerUid', isEqualTo: ownerUid).snapshots().map((snapshot) {
      final reminders = snapshot.docs.map((doc) => Reminder.fromJson(doc.id, doc.data())).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      return reminders;
    });
  }

  Future<void> create(Reminder reminder) async {
    debugPrint('ReminderRemoteDataSource.create: title=${reminder.title} ownerUid=${reminder.ownerUid}');
    await _firestore.collection('Reminders').add(reminder.toCreateJson());
  }

  Future<void> setCompleted(String id, bool completed) async {
    debugPrint('ReminderRemoteDataSource.setCompleted: id=$id completed=$completed');
    await _firestore.collection('Reminders').doc(id).update({'completed': completed});
  }

  Future<void> delete(String id) async {
    debugPrint('ReminderRemoteDataSource.delete: id=$id');
    await _firestore.collection('Reminders').doc(id).delete();
  }
}
