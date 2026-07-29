import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/compliance_log.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the local queue of not-yet-uploaded
/// compliance logs — mirrors [RcpaLocalDataSource] exactly (a JSON blob per
/// row, `mrUid` broken out as its own column for cheap filtering).
class ComplianceLogLocalDataSource {
  ComplianceLogLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(ComplianceLog log) async {
    debugPrint('ComplianceLogLocalDataSource.insert: id=${log.id} doctorId=${log.doctorId}');
    final db = await _database.database;
    await db.insert(
      'compliance_logs',
      {
        'id': log.id,
        'mrUid': log.mrUid,
        'data': jsonEncode(log.toJson()..['createdAt'] = log.createdAt.millisecondsSinceEpoch),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ComplianceLog>> getForMr(String mrUid) async {
    debugPrint('ComplianceLogLocalDataSource.getForMr: mrUid=$mrUid');
    final db = await _database.database;
    final rows = await db.query('compliance_logs', where: 'mrUid = ?', whereArgs: [mrUid]);
    return rows.map(_fromRow).toList();
  }

  Future<List<ComplianceLog>> getUnsynced() async {
    debugPrint('ComplianceLogLocalDataSource.getUnsynced: querying unsynced logs');
    final db = await _database.database;
    final rows = await db.query('compliance_logs', where: 'synced = 0');
    return rows.map(_fromRow).toList();
  }

  Future<int> countUnsynced() async {
    final db = await _database.database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM compliance_logs WHERE synced = 0'));
    return result ?? 0;
  }

  Future<void> markSynced(List<String> ids) async {
    debugPrint('ComplianceLogLocalDataSource.markSynced: marking ${ids.length} logs as synced');
    if (ids.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('compliance_logs', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  ComplianceLog _fromRow(Map<String, Object?> row) {
    final json = Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map);
    final createdAtMillis = json['createdAt'] as int?;
    json['createdAt'] = createdAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(createdAtMillis);
    return ComplianceLog.fromJson(row['id'] as String, json);
  }
}
