import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// An agency/pharmacy create an MR filled in while out in the field, queued
/// locally until the next sync uploads it as an `EntityChangeRequests` doc —
/// mirrors [PendingDoctorChangeRequest].
class PendingEntityChangeRequest {
  const PendingEntityChangeRequest({required this.localId, required this.data});

  final String localId;
  final Map<String, dynamic> data;
}

class EntityChangeRequestLocalDataSource {
  EntityChangeRequestLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(String localId, Map<String, dynamic> data) async {
    debugPrint('EntityChangeRequestLocalDataSource.insert: localId=$localId');
    final db = await _database.database;
    await db.insert(
      'entity_change_requests',
      {'localId': localId, 'data': jsonEncode(data), 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingEntityChangeRequest>> getUnsynced() async {
    debugPrint('EntityChangeRequestLocalDataSource.getUnsynced: querying unsynced change requests');
    final db = await _database.database;
    final rows = await db.query('entity_change_requests', where: 'synced = 0');
    return rows
        .map((row) => PendingEntityChangeRequest(
              localId: row['localId'] as String,
              data: Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map),
            ))
        .toList();
  }

  Future<int> countUnsynced() async {
    final db = await _database.database;
    final result =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM entity_change_requests WHERE synced = 0'));
    return result ?? 0;
  }

  Future<void> markSynced(List<String> localIds) async {
    debugPrint('EntityChangeRequestLocalDataSource.markSynced: marking ${localIds.length} requests as synced');
    if (localIds.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in localIds) {
      batch.update('entity_change_requests', {'synced': 1}, where: 'localId = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
