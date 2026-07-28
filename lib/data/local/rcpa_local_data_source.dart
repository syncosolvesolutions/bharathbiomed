import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/rcpa_entry.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the local queue of not-yet-uploaded RCPA
/// entries — mirrors [DoctorVisitLogLocalDataSource]'s write-then-forget
/// queue pattern, but stores the entry as a JSON blob (like `doctors`)
/// rather than one column per field, since [RcpaEntry] has nested
/// product/competitor count lists. `mrUid` is still its own indexed column
/// so [getForMr] doesn't need to parse every row's JSON to filter.
class RcpaLocalDataSource {
  RcpaLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(RcpaEntry entry) async {
    debugPrint('RcpaLocalDataSource.insert: id=${entry.id} pharmacyId=${entry.pharmacyId} date=${entry.auditDate}');
    final db = await _database.database;
    await db.insert(
      'rcpa_entries',
      {
        'id': entry.id,
        'mrUid': entry.mrUid,
        'data': jsonEncode(entry.toJson()..['createdAt'] = entry.createdAt.millisecondsSinceEpoch),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// All entries this MR has logged, synced or not — used to show "already
  /// audited this pharmacy today" without waiting for a sync.
  Future<List<RcpaEntry>> getForMr(String mrUid) async {
    debugPrint('RcpaLocalDataSource.getForMr: mrUid=$mrUid');
    final db = await _database.database;
    final rows = await db.query('rcpa_entries', where: 'mrUid = ?', whereArgs: [mrUid]);
    return rows.map(_fromRow).toList();
  }

  Future<List<RcpaEntry>> getUnsynced() async {
    debugPrint('RcpaLocalDataSource.getUnsynced: querying unsynced RCPA entries');
    final db = await _database.database;
    final rows = await db.query('rcpa_entries', where: 'synced = 0');
    debugPrint('RcpaLocalDataSource.getUnsynced: found ${rows.length} unsynced entries');
    return rows.map(_fromRow).toList();
  }

  Future<int> countUnsynced() async {
    final db = await _database.database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM rcpa_entries WHERE synced = 0'));
    return result ?? 0;
  }

  Future<void> markSynced(List<String> ids) async {
    debugPrint('RcpaLocalDataSource.markSynced: marking ${ids.length} entries as synced');
    if (ids.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('rcpa_entries', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  RcpaEntry _fromRow(Map<String, Object?> row) {
    final json = Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map);
    final createdAtMillis = json['createdAt'] as int?;
    json['createdAt'] = createdAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(createdAtMillis);
    return RcpaEntry.fromJson(row['id'] as String, json);
  }
}
