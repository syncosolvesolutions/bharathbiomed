import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/agency.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the offline agency cache — every signed-in
/// user can read agencies (see firestore.rules), so unlike doctors this
/// isn't scoped per-MR. JSON-blob-per-row, same rationale as
/// [DoctorLocalDataSource].
class AgencyLocalDataSource {
  AgencyLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Agency>> getAgencies() async {
    debugPrint('AgencyLocalDataSource.getAgencies: querying local agencies table');
    final db = await _database.database;
    final rows = await db.query('agencies');
    return rows.map((row) {
      final json = Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map);
      return Agency.fromJson(row['id'] as String, json);
    }).toList();
  }

  Future<void> replaceAll(List<Agency> agencies) async {
    debugPrint('AgencyLocalDataSource.replaceAll: replacing local cache with ${agencies.length} agencies');
    final db = await _database.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('agencies');
      for (final agency in agencies) {
        batch.insert(
          'agencies',
          {'id': agency.id, 'data': jsonEncode(agency.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
