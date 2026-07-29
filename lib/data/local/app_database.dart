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
    debugPrint('AppDatabase._open: opening catalog.db at version 10');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'catalog.db');
    final db = await openDatabase(
      path,
      version: 10,
      onCreate: (db, version) async {
        debugPrint('AppDatabase._open.onCreate: creating fresh database schema version=$version');
        await _createCatalogTables(db);
        await _createUsageSessionsTable(db);
        await _createDoctorTables(db);
        await _createAgencyPharmacyTables(db);
        await _createOrderTables(db);
        await _createRcpaTable(db);
        await _createExpenseClaimTable(db);
        await _createLeaveRequestTable(db);
        await _createComplianceLogTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('AppDatabase._open.onUpgrade: upgrading database oldVersion=$oldVersion newVersion=$newVersion');
        if (oldVersion < 2) {
          await _createUsageSessionsTable(db);
        }
        if (oldVersion < 3) {
          await _createDoctorTables(db);
        }
        if (oldVersion < 4) {
          await _createAgencyPharmacyTables(db);
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE products ADD COLUMN stockQuantity INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE products ADD COLUMN unitPrice REAL NOT NULL DEFAULT 0');
          await _createOrderTables(db);
        }
        if (oldVersion < 6) {
          await _createRcpaTable(db);
        }
        if (oldVersion < 7) {
          await db.execute("ALTER TABLE doctor_visit_logs ADD COLUMN samplesGiven TEXT NOT NULL DEFAULT '{}'");
        }
        if (oldVersion < 8) {
          await _createExpenseClaimTable(db);
        }
        if (oldVersion < 9) {
          await _createLeaveRequestTable(db);
        }
        if (oldVersion < 10) {
          await _createComplianceLogTable(db);
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
        imageUrl TEXT NOT NULL,
        stockQuantity INTEGER NOT NULL DEFAULT 0,
        unitPrice REAL NOT NULL DEFAULT 0
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
        samplesGiven TEXT NOT NULL DEFAULT '{}',
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Agencies/pharmacies feature tables:
  /// - `agencies`/`pharmacies`: local cache of every agency/pharmacy (every
  ///   signed-in user can read these — not scoped per-MR like doctors), one
  ///   JSON blob row per entity, same rationale as `doctors`.
  /// - `entity_change_requests`: a queue of not-yet-uploaded agency/pharmacy
  ///   create proposals an MR made in the field, mirrors
  ///   `doctor_change_requests`.
  Future<void> _createAgencyPharmacyTables(Database db) async {
    debugPrint('AppDatabase._createAgencyPharmacyTables: creating agency/pharmacy feature tables');
    await db.execute('''
      CREATE TABLE agencies (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pharmacies (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE entity_change_requests (
        localId TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// `orders`: a queue of not-yet-uploaded MR-placed orders, mirrors
  /// `doctor_change_requests`/`entity_change_requests` — once uploaded, the
  /// live status (approved/dispatched/invoiced) is only ever read from
  /// Firestore directly (`OrderRepository.fetchMine`), not re-cached here,
  /// since this table's only job is "does this still need to reach the
  /// server."
  Future<void> _createOrderTables(Database db) async {
    debugPrint('AppDatabase._createOrderTables: creating orders table');
    await db.execute('''
      CREATE TABLE orders (
        localId TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// `rcpa_entries`: a queue of not-yet-uploaded Retail Chemist Prescription
  /// Audit entries — append-only like `doctor_visit_logs`, but a JSON blob
  /// per row (like `doctors`) since an entry has nested own-brand/competitor
  /// count lists rather than flat scalar fields. `mrUid` is still its own
  /// column so filtering "this MR's entries" doesn't need to parse JSON.
  Future<void> _createRcpaTable(Database db) async {
    debugPrint('AppDatabase._createRcpaTable: creating rcpa_entries table');
    await db.execute('''
      CREATE TABLE rcpa_entries (
        id TEXT PRIMARY KEY,
        mrUid TEXT NOT NULL,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// `expense_claims`: a queue of not-yet-uploaded MR-filed TA/DA claims,
  /// same shape/rationale as `orders` — once uploaded, live status
  /// (approved/rejected) is only ever read from Firestore directly
  /// (`ExpenseClaimRepository.fetchMine`), not re-cached here.
  Future<void> _createExpenseClaimTable(Database db) async {
    debugPrint('AppDatabase._createExpenseClaimTable: creating expense_claims table');
    await db.execute('''
      CREATE TABLE expense_claims (
        localId TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// `leave_requests`: a queue of not-yet-uploaded MR-filed leave requests —
  /// identical shape to `expense_claims`.
  Future<void> _createLeaveRequestTable(Database db) async {
    debugPrint('AppDatabase._createLeaveRequestTable: creating leave_requests table');
    await db.execute('''
      CREATE TABLE leave_requests (
        localId TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// `compliance_logs`: a queue of not-yet-uploaded UCPMP compliance
  /// records — identical shape to `rcpa_entries` (a JSON blob per row,
  /// `mrUid` broken out as its own column).
  Future<void> _createComplianceLogTable(Database db) async {
    debugPrint('AppDatabase._createComplianceLogTable: creating compliance_logs table');
    await db.execute('''
      CREATE TABLE compliance_logs (
        id TEXT PRIMARY KEY,
        mrUid TEXT NOT NULL,
        data TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
