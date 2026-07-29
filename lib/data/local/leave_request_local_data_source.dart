import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// A leave request an MR filed while out in the field, queued locally until
/// the next sync uploads it — mirrors [PendingExpenseClaim].
class PendingLeaveRequest {
  const PendingLeaveRequest({required this.localId, required this.data});

  final String localId;
  final Map<String, dynamic> data;
}

class LeaveRequestLocalDataSource {
  LeaveRequestLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(String localId, Map<String, dynamic> data) async {
    debugPrint('LeaveRequestLocalDataSource.insert: localId=$localId');
    final db = await _database.database;
    await db.insert(
      'leave_requests',
      {'localId': localId, 'data': jsonEncode(data), 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingLeaveRequest>> getUnsynced() async {
    debugPrint('LeaveRequestLocalDataSource.getUnsynced: querying unsynced requests');
    final db = await _database.database;
    final rows = await db.query('leave_requests', where: 'synced = 0');
    return rows
        .map((row) => PendingLeaveRequest(
              localId: row['localId'] as String,
              data: Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map),
            ))
        .toList();
  }

  Future<int> countUnsynced() async {
    final db = await _database.database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM leave_requests WHERE synced = 0'));
    return result ?? 0;
  }

  Future<void> markSynced(List<String> localIds) async {
    debugPrint('LeaveRequestLocalDataSource.markSynced: marking ${localIds.length} requests as synced');
    if (localIds.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in localIds) {
      batch.update('leave_requests', {'synced': 1}, where: 'localId = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
