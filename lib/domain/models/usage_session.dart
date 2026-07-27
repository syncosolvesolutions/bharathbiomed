import 'package:equatable/equatable.dart';

/// One "app open to app close" span for a Medical Representative, plus the
/// device's location at open time. Recorded locally while offline (see
/// UsageSessionLocalDataSource) and uploaded to Firestore the next time the
/// device syncs (see UsageSessionRepository.uploadPending). Never recorded
/// for the admin's own account.
class UsageSession extends Equatable {
  final String id;
  final String employeeUid;
  final String username;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double? latitude;
  final double? longitude;

  const UsageSession({
    required this.id,
    required this.employeeUid,
    required this.username,
    required this.openedAt,
    this.closedAt,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  Duration? get duration => closedAt?.difference(openedAt);

  @override
  List<Object?> get props => [id, employeeUid, username, openedAt, closedAt, latitude, longitude];
}
