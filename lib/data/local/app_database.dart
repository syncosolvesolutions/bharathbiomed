import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single sqflite entry point for the app's local catalog cache (and, since
/// v2, the local queue of not-yet-uploaded MR usage sessions).
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      debugPrint('AppDatabase.database: returning cached database instance');
      return _database!;
    }
    debugPrint('AppDatabase.database: no cached instance, opening database');
    return _database ??= await _open();
  }

  Future<Database> _open() async {
    debugPrint('AppDatabase._open: opening catalog.db at version 2');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'catalog.db');
    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        debugPrint('AppDatabase._open.onCreate: creating fresh database schema version=$version');
        await _createCatalogTables(db);
        await _createUsageSessionsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('AppDatabase._open.onUpgrade: upgrading database oldVersion=$oldVersion newVersion=$newVersion');
        if (oldVersion < 2) {
          await _createUsageSessionsTable(db);
        }
      },
    );
    debugPrint('AppDatabase._open: database opened successfully path=$path');
    return db;
  }

  Future<void> _createCatalogTables(Database db) async {
    debugPrint('AppDatabase._createCatalogTables: creating products and departments tables');
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        info TEXT NOT NULL,
        departments TEXT NOT NULL,
        imageUrl TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE departments (
        name TEXT PRIMARY KEY,
        position INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createUsageSessionsTable(Database db) async {
    debugPrint('AppDatabase._createUsageSessionsTable: creating usage_sessions table');
    await db.execute('''
      CREATE TABLE usage_sessions (
        id TEXT PRIMARY KEY,
        employeeUid TEXT NOT NULL,
        username TEXT NOT NULL,
        openedAt INTEGER NOT NULL,
        closedAt INTEGER,
        latitude REAL,
        longitude REAL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
