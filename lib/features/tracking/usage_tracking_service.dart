import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/admin_access.dart';
import '../../data/providers.dart';
import 'location_service.dart';

final usageTrackingServiceProvider = Provider<UsageTrackingService>((ref) => UsageTrackingService(ref));

/// Starts/closes a local [UsageSession] as the app resumes/pauses, for
/// Medical Representative accounts only (never the admin's own usage). See
/// docs/BUSINESS_OVERVIEW.md for why this exists and what it's used for.
///
/// This only ever touches the *local* sqflite queue — getting that queue to
/// Firestore is UsageSessionRepository.uploadPending, called alongside the
/// existing catalog sync.
class UsageTrackingService {
  UsageTrackingService(this._ref);

  final Ref _ref;
  final _locationService = LocationService();
  String? _activeSessionId;

  Future<void> handleAppResumed(User? user) async {
    debugPrint('UsageTrackingService.handleAppResumed: called for uid=${user?.uid}');
    if (user == null || isAdminEmail(user.email) || _activeSessionId != null) return;

    debugPrint('UsageTrackingService.handleAppResumed: fetching best-effort location');
    final position = await _locationService.getCurrentLocationBestEffort();
    debugPrint('UsageTrackingService.handleAppResumed: starting usage session');
    _activeSessionId = await _ref.read(usageSessionRepositoryProvider).startSession(
          employeeUid: user.uid,
          username: user.displayName ?? user.email ?? user.uid,
          latitude: position?.latitude,
          longitude: position?.longitude,
        );
    debugPrint('UsageTrackingService.handleAppResumed: session started id=$_activeSessionId');
  }

  Future<void> handleAppPaused() async {
    debugPrint('UsageTrackingService.handleAppPaused: called, activeSessionId=$_activeSessionId');
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    _activeSessionId = null;
    debugPrint('UsageTrackingService.handleAppPaused: closing session id=$sessionId');
    await _ref.read(usageSessionRepositoryProvider).closeSession(sessionId);
    debugPrint('UsageTrackingService.handleAppPaused: session closed successfully');
  }
}
