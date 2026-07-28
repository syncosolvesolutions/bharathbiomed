import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/doctor_visit_log.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the local queue of not-yet-uploaded doctor
/// visit logs — mirrors [UsageSessionLocalDataSource]'s write-then-forget
/// queue pattern.
class DoctorVisitLogLocalDataSource {
  DoctorVisitLogLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(DoctorVisitLog log) async {
    debugPrint('DoctorVisitLogLocalDataSource.insert: id=${log.id} doctorId=${log.doctorId} date=${log.visitDate}');
    final db = await _database.database;
    await db.insert(
      'doctor_visit_logs',
      {
        'id': log.id,
        'mrUid': log.mrUid,
        'doctorId': log.doctorId,
        'doctorName': log.doctorName,
        'visitDate': log.visitDate,
        'visited': log.visited ? 1 : 0,
        'feedback': log.feedback,
        'latitude': log.latitude,
        'longitude': log.longitude,
        'createdAt': log.createdAt.millisecondsSinceEpoch,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// All logs recorded for [mrUid] today or earlier, synced or not — used to
  /// show "already logged today" state on the Today's Visits screen without
  /// waiting for a sync.
  Future<List<DoctorVisitLog>> getForMr(String mrUid) async {
    debugPrint('DoctorVisitLogLocalDataSource.getForMr: mrUid=$mrUid');
    final db = await _database.database;
    final rows = await db.query('doctor_visit_logs', where: 'mrUid = ?', whereArgs: [mrUid]);
    return rows.map(_fromRow).toList();
  }

  Future<List<DoctorVisitLog>> getUnsynced() async {
    debugPrint('DoctorVisitLogLocalDataSource.getUnsynced: querying unsynced visit logs');
    final db = await _database.database;
    final rows = await db.query('doctor_visit_logs', where: 'synced = 0');
    debugPrint('DoctorVisitLogLocalDataSource.getUnsynced: found ${rows.length} unsynced logs');
    return rows.map(_fromRow).toList();
  }

  Future<void> markSynced(List<String> ids) async {
    debugPrint('DoctorVisitLogLocalDataSource.markSynced: marking ${ids.length} logs as synced');
    if (ids.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('doctor_visit_logs', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  DoctorVisitLog _fromRow(Map<String, Object?> row) {
    return DoctorVisitLog(
      id: row['id'] as String,
      mrUid: row['mrUid'] as String,
      doctorId: row['doctorId'] as String,
      doctorName: row['doctorName'] as String,
      visitDate: row['visitDate'] as String,
      visited: (row['visited'] as int) == 1,
      feedback: row['feedback'] as String,
      latitude: row['latitude'] as double?,
      longitude: row['longitude'] as double?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
    );
  }
}
