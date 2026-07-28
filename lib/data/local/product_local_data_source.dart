import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/product.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the catalog cache. No business rules live
/// here — that's [ProductRepository]'s job; this class only knows SQL.
class ProductLocalDataSource {
  ProductLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<Product>> getProducts() async {
    debugPrint('ProductLocalDataSource.getProducts: querying local products table');
    final db = await _database.database;
    final rows = await db.query('products');
    debugPrint('ProductLocalDataSource.getProducts: retrieved ${rows.length} rows');
    return rows
        .map((row) => Product(
              id: row['id'] as String,
              name: row['name'] as String,
              info: row['info'] as String,
              departments: Map<String, int>.from(jsonDecode(row['departments'] as String) as Map),
              imageUrl: row['imageUrl'] as String,
              stockQuantity: row['stockQuantity'] as int? ?? 0,
              unitPrice: (row['unitPrice'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Future<List<String>> getDepartments() async {
    debugPrint('ProductLocalDataSource.getDepartments: querying local departments table');
    final db = await _database.database;
    final rows = await db.query('departments', orderBy: 'position ASC');
    debugPrint('ProductLocalDataSource.getDepartments: retrieved ${rows.length} rows');
    return rows.map((row) => row['name'] as String).toList();
  }

  /// Replaces the entire local cache with [products]/[departments] in one transaction.
  Future<void> replaceAll({
    required List<Product> products,
    required List<String> departments,
  }) async {
    debugPrint(
        'ProductLocalDataSource.replaceAll: replacing local cache with ${products.length} products and ${departments.length} departments');
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
            'stockQuantity': product.stockQuantity,
            'unitPrice': product.unitPrice,
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
    debugPrint('ProductLocalDataSource.replaceAll: local cache replaced successfully');
  }
}
