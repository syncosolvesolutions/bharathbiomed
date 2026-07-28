import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/usage_session.dart';
import '../local/usage_session_local_data_source.dart';
import '../remote/usage_session_remote_data_source.dart';

/// MR app-usage tracking, offline-first like the rest of this app: sessions
/// are recorded locally as they happen (see [startSession]/[closeSession])
/// and only reach Firestore via [uploadPending], called alongside the
/// existing catalog sync rather than automatically on connectivity change —
/// this app doesn't make unprompted network calls.
class UsageSessionRepository {
  UsageSessionRepository({
    UsageSessionLocalDataSource? local,
    UsageSessionRemoteDataSource? remote,
  })  : _local = local ?? UsageSessionLocalDataSource(),
        _remote = remote ?? UsageSessionRemoteDataSource();

  final UsageSessionLocalDataSource _local;
  final UsageSessionRemoteDataSource _remote;

  /// Returns the new session's local id, to be passed back to [closeSession]
  /// once the app pauses/closes.
  Future<String> startSession({
    required String employeeUid,
    required String username,
    double? latitude,
    double? longitude,
  }) async {
    debugPrint('UsageSessionRepository.startSession: starting session employeeUid=$employeeUid username=$username');
    await _local.closeDanglingSessions(employeeUid);

    final id = const Uuid().v4();
    await _local.insert(UsageSession(
      id: id,
      employeeUid: employeeUid,
      username: username,
      openedAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    ));
    debugPrint('UsageSessionRepository.startSession: started session id=$id');
    return id;
  }

  Future<void> closeSession(String id) {
    debugPrint('UsageSessionRepository.closeSession: closing session id=$id');
    return _local.close(id, DateTime.now());
  }

  /// Best-effort: never lets a telemetry upload failure interrupt whatever
  /// triggered it (the catalog sync).
  Future<void> uploadPending() async {
    debugPrint('UsageSessionRepository.uploadPending: checking for unsynced sessions');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('UsageSessionRepository.uploadPending: no pending sessions to upload');
      return;
    }
    debugPrint('UsageSessionRepository.uploadPending: uploading ${pending.length} pending sessions');
    await _remote.upload(pending);
    await _local.markSynced(pending.map((session) => session.id).toList());
    debugPrint('UsageSessionRepository.uploadPending: upload and local sync-marking complete');
  }

  Future<List<UsageSession>> fetchRecentForDashboard() {
    debugPrint('UsageSessionRepository.fetchRecentForDashboard: fetching recent sessions for dashboard');
    return _remote.fetchRecent();
  }
}
