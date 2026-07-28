import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/doctor.dart';
import '../../domain/models/doctor_visit_plan.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the offline doctor cache — an MR's assigned
/// doctors (or, for the admin, the whole roster), plus this device's own
/// weekly visit plan. Rows store the model's JSON verbatim rather than one
/// column per field: unlike products, this model's shape has kept growing
/// through this feature's design (photos, location, plan/assignment), and a
/// JSON blob avoids a schema migration every time another optional field is
/// added.
class DoctorLocalDataSource {
  DoctorLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<bool> hasDoctors() async {
    debugPrint('DoctorLocalDataSource.hasDoctors: checking local doctors count');
    final db = await _database.database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM doctors'));
    return (result ?? 0) > 0;
  }

  Future<List<Doctor>> getDoctors() async {
    debugPrint('DoctorLocalDataSource.getDoctors: querying local doctors table');
    final db = await _database.database;
    final rows = await db.query('doctors');
    debugPrint('DoctorLocalDataSource.getDoctors: retrieved ${rows.length} rows');
    return rows.map((row) {
      final json = Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map);
      return Doctor.fromJson(row['id'] as String, json);
    }).toList();
  }

  /// Replaces the entire local doctor cache — mirrors
  /// [ProductLocalDataSource.replaceAll]'s all-or-nothing approach so a sync
  /// can't leave a mix of old and new doctors around.
  Future<void> replaceAll(List<Doctor> doctors) async {
    debugPrint('DoctorLocalDataSource.replaceAll: replacing local cache with ${doctors.length} doctors');
    final db = await _database.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('doctors');
      for (final doctor in doctors) {
        batch.insert(
          'doctors',
          {'id': doctor.id, 'data': jsonEncode(doctor.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    debugPrint('DoctorLocalDataSource.replaceAll: local cache replaced successfully');
  }

  Future<DoctorVisitPlan?> getVisitPlan(String mrUid) async {
    debugPrint('DoctorLocalDataSource.getVisitPlan: mrUid=$mrUid');
    final db = await _database.database;
    final rows = await db.query('doctor_visit_plan', where: 'mrUid = ?', whereArgs: [mrUid], limit: 1);
    if (rows.isEmpty) return null;
    final json = Map<String, dynamic>.from(jsonDecode(rows.first['data'] as String) as Map);
    return DoctorVisitPlan.fromJson(mrUid, json);
  }

  /// [synced] is `false` when this save couldn't reach Firestore (offline
  /// edit) — [DoctorVisitPlanRepository.pushUnsyncedPlan] retries it on the
  /// next sync.
  Future<void> saveVisitPlan(DoctorVisitPlan plan, {required bool synced}) async {
    debugPrint('DoctorLocalDataSource.saveVisitPlan: mrUid=${plan.mrUid} synced=$synced');
    final db = await _database.database;
    await db.insert(
      'doctor_visit_plan',
      {'mrUid': plan.mrUid, 'data': jsonEncode(plan.toJson()), 'synced': synced ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> hasUnsyncedVisitPlan(String mrUid) async {
    final db = await _database.database;
    final rows = await db.query('doctor_visit_plan', where: 'mrUid = ? AND synced = 0', whereArgs: [mrUid]);
    return rows.isNotEmpty;
  }

  Future<void> markVisitPlanSynced(String mrUid) async {
    debugPrint('DoctorLocalDataSource.markVisitPlanSynced: mrUid=$mrUid');
    final db = await _database.database;
    await db.update('doctor_visit_plan', {'synced': 1}, where: 'mrUid = ?', whereArgs: [mrUid]);
  }
}
