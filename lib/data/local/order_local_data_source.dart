import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// An order an MR placed while out in the field, queued locally until the
/// next sync uploads it — mirrors [PendingDoctorChangeRequest].
class PendingOrder {
  const PendingOrder({required this.localId, required this.data});

  final String localId;
  final Map<String, dynamic> data;
}

class OrderLocalDataSource {
  OrderLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(String localId, Map<String, dynamic> data) async {
    debugPrint('OrderLocalDataSource.insert: localId=$localId');
    final db = await _database.database;
    await db.insert(
      'orders',
      {'localId': localId, 'data': jsonEncode(data), 'synced': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingOrder>> getUnsynced() async {
    debugPrint('OrderLocalDataSource.getUnsynced: querying unsynced orders');
    final db = await _database.database;
    final rows = await db.query('orders', where: 'synced = 0');
    return rows
        .map((row) => PendingOrder(
              localId: row['localId'] as String,
              data: Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map),
            ))
        .toList();
  }

  Future<int> countUnsynced() async {
    final db = await _database.database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM orders WHERE synced = 0'));
    return result ?? 0;
  }

  Future<void> markSynced(List<String> localIds) async {
    debugPrint('OrderLocalDataSource.markSynced: marking ${localIds.length} orders as synced');
    if (localIds.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in localIds) {
      batch.update('orders', {'synced': 1}, where: 'localId = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
