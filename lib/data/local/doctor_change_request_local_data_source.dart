import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// A doctor create/edit an MR filled in while out in the field, queued
/// locally until the evening sync uploads it as a `DoctorChangeRequests`
/// doc (see requirement 11/12: offline-first, sync later). [localId] is
/// reused as the Firestore doc id on upload so a retried upload after a
/// partial failure overwrites the same doc instead of duplicating it —
/// same trick as [UsageSession.id].
class PendingDoctorChangeRequest {
  const PendingDoctorChangeRequest({required this.localId, required this.data});

  final String localId;
  final Map<String, dynamic> data;
}

class DoctorChangeRequestLocalDataSource {
  DoctorChangeRequestLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(String localId, Map<String, dynamic> data) async {
    debugPrint('DoctorChangeRequestLocalDataSource.insert: localId=$localId');
    final db = await _database.database;
    await db.insert(
      'doctor_change_requests',
      {'localId': localId, 'data': jsonEncode(data), 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingDoctorChangeRequest>> getUnsynced() async {
    debugPrint('DoctorChangeRequestLocalDataSource.getUnsynced: querying unsynced change requests');
    final db = await _database.database;
    final rows = await db.query('doctor_change_requests', where: 'synced = 0');
    debugPrint('DoctorChangeRequestLocalDataSource.getUnsynced: found ${rows.length} unsynced requests');
    return rows
        .map((row) => PendingDoctorChangeRequest(
              localId: row['localId'] as String,
              data: Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map),
            ))
        .toList();
  }

  Future<int> countUnsynced() async {
    final db = await _database.database;
    final result =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM doctor_change_requests WHERE synced = 0'));
    return result ?? 0;
  }

  Future<void> markSynced(List<String> localIds) async {
    debugPrint('DoctorChangeRequestLocalDataSource.markSynced: marking ${localIds.length} requests as synced');
    if (localIds.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in localIds) {
      batch.update('doctor_change_requests', {'synced': 1}, where: 'localId = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
