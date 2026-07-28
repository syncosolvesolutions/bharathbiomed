import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/pharmacy.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the offline pharmacy cache — mirrors
/// [AgencyLocalDataSource]; every signed-in user can read pharmacies.
class PharmacyLocalDataSource {
  PharmacyLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Pharmacy>> getPharmacies() async {
    debugPrint('PharmacyLocalDataSource.getPharmacies: querying local pharmacies table');
    final db = await _database.database;
    final rows = await db.query('pharmacies');
    return rows.map((row) {
      final json = Map<String, dynamic>.from(jsonDecode(row['data'] as String) as Map);
      return Pharmacy.fromJson(row['id'] as String, json);
    }).toList();
  }

  Future<void> replaceAll(List<Pharmacy> pharmacies) async {
    debugPrint('PharmacyLocalDataSource.replaceAll: replacing local cache with ${pharmacies.length} pharmacies');
    final db = await _database.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('pharmacies');
      for (final pharmacy in pharmacies) {
        batch.insert(
          'pharmacies',
          {'id': pharmacy.id, 'data': jsonEncode(pharmacy.toJson())},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
