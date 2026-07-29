import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// An expense claim an MR filed while out in the field, queued locally
/// until the next sync uploads it — mirrors [PendingOrder].
class PendingExpenseClaim {
  const PendingExpenseClaim({required this.localId, required this.data});

  final String localId;
  final Map<String, dynamic> data;
}

class ExpenseClaimLocalDataSource {
  ExpenseClaimLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(String localId, Map<String, dynamic> data) async {
    debugPrint('ExpenseClaimLocalDataSource.insert: localId=$localId');
    final db = await _database.database;
    await db.insert(
      'expense_claims',
      {'localId': localId, 'data': jsonEncode(data), 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingExpenseClaim>> getUnsynced() async {
    debugPrint('ExpenseClaimLocalDataSource.getUnsynced: querying unsynced claims');
    final db = await _database.database;
    final rows = await db.query('expense_claims', where: 'synced = 0');
    return rows
        .map((row) => PendingExpenseClaim(
              localId: row['localId'] as String,
              data: Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map),
            ))
        .toList();
  }

  Future<int> countUnsynced() async {
    final db = await _database.database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM expense_claims WHERE synced = 0'));
    return result ?? 0;
  }

  Future<void> markSynced(List<String> localIds) async {
    debugPrint('ExpenseClaimLocalDataSource.markSynced: marking ${localIds.length} claims as synced');
    if (localIds.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in localIds) {
      batch.update('expense_claims', {'synced': 1}, where: 'localId = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
