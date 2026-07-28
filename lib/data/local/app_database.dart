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
    debugPrint('AppDatabase._open: opening catalog.db at version 3');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'catalog.db');
    final db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        debugPrint('AppDatabase._open.onCreate: creating fresh database schema version=$version');
        await _createCatalogTables(db);
        await _createUsageSessionsTable(db);
        await _createDoctorTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('AppDatabase._open.onUpgrade: upgrading database oldVersion=$oldVersion newVersion=$newVersion');
        if (oldVersion < 2) {
          await _createUsageSessionsTable(db);
        }
        if (oldVersion < 3) {
          await _createDoctorTables(db);
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

  /// Doctors feature tables:
  /// - `doctors`: local cache of the doctors this device last synced (an
  ///   MR's assigned doctors, or the whole list for the admin), read offline.
  /// - `doctor_visit_plan`: this device's own MR's weekly plan, cached as a
  ///   single JSON blob row keyed by `mrUid` (there's only ever one row for
  ///   whoever is signed in on this device).
  /// - `doctor_change_requests`: a queue of not-yet-uploaded doctor
  ///   create/edit proposals an MR made in the field.
  /// - `doctor_visit_logs`: a queue of not-yet-uploaded daily visit/feedback
  ///   entries, mirroring `usage_sessions`.
  Future<void> _createDoctorTables(Database db) async {
    debugPrint('AppDatabase._createDoctorTables: creating doctors feature tables');
    await db.execute('''
      CREATE TABLE doctors (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE doctor_visit_plan (
        mrUid TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE doctor_change_requests (
        localId TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE doctor_visit_logs (
        id TEXT PRIMARY KEY,
        mrUid TEXT NOT NULL,
        doctorId TEXT NOT NULL,
        doctorName TEXT NOT NULL,
        visitDate TEXT NOT NULL,
        visited INTEGER NOT NULL,
        feedback TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        createdAt INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
