import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/models/product.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the catalog cache. No business rules live
/// here — that's [ProductRepository]'s job; this class only knows SQL.
class ProductLocalDataSource {
  ProductLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Product>> getProducts() async {
    final db = await _database.database;
    final rows = await db.query('products');
    return rows
        .map((row) => Product(
              id: row['id'] as String,
              name: row['name'] as String,
              info: row['info'] as String,
              departments: Map<String, int>.from(jsonDecode(row['departments'] as String) as Map),
              imageUrl: row['imageUrl'] as String,
            ))
        .toList();
  }

  Future<List<String>> getDepartments() async {
    final db = await _database.database;
    final rows = await db.query('departments', orderBy: 'position ASC');
    return rows.map((row) => row['name'] as String).toList();
  }

  /// Replaces the entire local cache with [products]/[departments] in one transaction.
  Future<void> replaceAll({
    required List<Product> products,
    required List<String> departments,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      batch.delete('products');
      batch.delete('departments');
      for (final product in products) {
        batch.insert(
          'products',
          {
            'id': product.id,
            'name': product.name,
            'info': product.info,
            'departments': jsonEncode(product.departments),
            'imageUrl': product.imageUrl,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (var i = 0; i < departments.length; i++) {
        batch.insert(
          'departments',
          {'name': departments[i], 'position': i},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
