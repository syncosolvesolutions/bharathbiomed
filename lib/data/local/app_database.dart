import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single sqflite entry point for the app's local catalog cache (and, since
/// v2, the local queue of not-yet-uploaded MR usage sessions).
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    return _database ??= await _open();
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'catalog.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createCatalogTables(db);
        await _createUsageSessionsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createUsageSessionsTable(db);
        }
      },
    );
  }

  Future<void> _createCatalogTables(Database db) async {
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
