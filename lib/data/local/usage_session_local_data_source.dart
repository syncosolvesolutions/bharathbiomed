import 'package:flutter/foundation.dart';

import '../../domain/models/usage_session.dart';
import 'app_database.dart';

/// Raw sqflite reads/writes for the local queue of MR usage sessions. This
/// is a write-then-forget queue: [getUnsynced] and [markSynced] are how
/// UsageSessionRepository drains it to Firestore once the device is online.
class UsageSessionLocalDataSource {
  UsageSessionLocalDataSource({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> insert(UsageSession session) async {
    debugPrint('UsageSessionLocalDataSource.insert: inserting session id=${session.id} employeeUid=${session.employeeUid}');
    final db = await _database.database;
    await db.insert('usage_sessions', {
      'id': session.id,
      'employeeUid': session.employeeUid,
      'username': session.username,
      'openedAt': session.openedAt.millisecondsSinceEpoch,
      'closedAt': session.closedAt?.millisecondsSinceEpoch,
      'latitude': session.latitude,
      'longitude': session.longitude,
      'synced': 0,
    });
    debugPrint('UsageSessionLocalDataSource.insert: inserted session id=${session.id}');
  }

  Future<void> close(String id, DateTime closedAt) async {
    debugPrint('UsageSessionLocalDataSource.close: closing session id=$id closedAt=$closedAt');
    final db = await _database.database;
    await db.update(
      'usage_sessions',
      {'closedAt': closedAt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Closes any session left open from a previous run — e.g. the app was
  /// killed without a clean pause/detached lifecycle event, so nothing ever
  /// called [close]. Uses the session's own `openedAt` as `closedAt` (0
  /// duration) since there's no better data, rather than letting it linger
  /// as "still open" forever on the admin dashboard.
  Future<void> closeDanglingSessions(String employeeUid) async {
    debugPrint('UsageSessionLocalDataSource.closeDanglingSessions: employeeUid=$employeeUid');
    final db = await _database.database;
    final rows = await db.query(
      'usage_sessions',
      columns: ['id', 'openedAt'],
      where: 'employeeUid = ? AND closedAt IS NULL',
      whereArgs: [employeeUid],
    );
    debugPrint('UsageSessionLocalDataSource.closeDanglingSessions: found ${rows.length} dangling sessions');
    for (final row in rows) {
      await db.update(
        'usage_sessions',
        {'closedAt': row['openedAt']},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<List<UsageSession>> getUnsynced() async {
    debugPrint('UsageSessionLocalDataSource.getUnsynced: querying unsynced closed sessions');
    final db = await _database.database;
    final rows = await db.query(
      'usage_sessions',
      where: 'synced = 0 AND closedAt IS NOT NULL',
    );
    debugPrint('UsageSessionLocalDataSource.getUnsynced: found ${rows.length} unsynced sessions');
    return rows.map(_fromRow).toList();
  }

  Future<void> markSynced(List<String> ids) async {
    debugPrint('UsageSessionLocalDataSource.markSynced: marking ${ids.length} sessions as synced');
    if (ids.isEmpty) return;
    final db = await _database.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('usage_sessions', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  UsageSession _fromRow(Map<String, Object?> row) {
    final closedAt = row['closedAt'] as int?;
    return UsageSession(
      id: row['id'] as String,
      employeeUid: row['employeeUid'] as String,
      username: row['username'] as String,
      openedAt: DateTime.fromMillisecondsSinceEpoch(row['openedAt'] as int),
      closedAt: closedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(closedAt),
      latitude: row['latitude'] as double?,
      longitude: row['longitude'] as double?,
    );
  }
}
