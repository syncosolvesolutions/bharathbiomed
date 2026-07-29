import 'package:equatable/equatable.dart';

import '../../core/utils/date_of_birth.dart';
import '../../domain/models/usage_session.dart';

/// One calendar day's derived attendance for one employee: whether they
/// opened the app at all that day, and if so, when first/last and how many
/// times. This is *derived*, not stored — there is no `Attendance`
/// Firestore collection; it's computed client-side from [UsageSession]
/// records the app already uploads for the usage dashboard (see
/// `features/admin/usage_dashboard_controller.dart`). "Present" here means
/// "opened the app" (a proxy signal), not a verified physical check-in —
/// this is oversight-grade attendance, not a payroll-grade one, same as the
/// rest of this app's usage tracking.
class AttendanceDay extends Equatable {
  final String date;
  final DateTime firstCheckIn;

  /// The latest session's `closedAt` that day, or that same session's own
  /// `openedAt` if it was never closed (e.g. the app crashed) — always
  /// present, never a true "unknown", see [deriveAttendanceDays].
  final DateTime lastCheckOut;
  final int sessionCount;
  final bool hasLocation;

  const AttendanceDay({
    required this.date,
    required this.firstCheckIn,
    required this.lastCheckOut,
    required this.sessionCount,
    required this.hasLocation,
  });

  @override
  List<Object?> get props => [date, firstCheckIn, lastCheckOut, sessionCount, hasLocation];
}

/// Groups [sessions] by the local calendar date of [UsageSession.openedAt]
/// and reduces each group to one [AttendanceDay] — earliest open as
/// check-in, latest close (falling back to that session's own open time if
/// it was never closed, e.g. the app crashed) as check-out. Sorted most
/// recent day first. Pure function, no I/O — safe to unit test directly and
/// to reuse for both a single MR's own view and a manager's per-employee
/// drill-down.
List<AttendanceDay> deriveAttendanceDays(List<UsageSession> sessions) {
  final byDate = <String, List<UsageSession>>{};
  for (final session in sessions) {
    final date = isoFromDate(session.openedAt);
    byDate.putIfAbsent(date, () => []).add(session);
  }

  final days = byDate.entries.map((entry) {
    final daySessions = entry.value;
    final firstCheckIn = daySessions.map((s) => s.openedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final closeTimes = daySessions.map((s) => s.closedAt ?? s.openedAt).toList();
    final lastCheckOut = closeTimes.reduce((a, b) => a.isAfter(b) ? a : b);
    return AttendanceDay(
      date: entry.key,
      firstCheckIn: firstCheckIn,
      lastCheckOut: lastCheckOut,
      sessionCount: daySessions.length,
      hasLocation: daySessions.any((s) => s.hasLocation),
    );
  }).toList();

  days.sort((a, b) => b.date.compareTo(a.date));
  return days;
}
