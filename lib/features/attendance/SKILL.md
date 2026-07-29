# Attendance feature

Day-by-day attendance, **derived** from the existing `UsageSession`
records (`features/tracking/`) — there is no `Attendance` Firestore
collection and no new backend surface here at all, which is why this
feature needed no `firestore.rules` changes and no new permission. If it's
recorded for the usage dashboard, it's available here for free.

"Present" means "opened the app that day" — a proxy signal already
described to users in the Privacy Policy (see
`lib/features/legal/legal_content.dart`'s "attendance purposes" mention),
not a verified physical check-in. This is oversight-grade, not
payroll-grade.

## Files

- `attendance_day.dart` — the only real logic here: `AttendanceDay` (one
  calendar day's derived summary) and `deriveAttendanceDays`, a pure
  function (`List<UsageSession> -> List<AttendanceDay>`, grouped by local
  calendar date of `openedAt`). No I/O — see
  `test/features/attendance/attendance_day_test.dart` for direct unit
  tests, no mocking needed.
- `my_attendance_controller.dart` / `my_attendance_screen.dart` — the
  signed-in MR's own attendance (route `/attendance`). This is the first
  screen where an MR can see their own usage-session history at all; it
  was admin/manager-only before (see `docs/TODO.md`'s now-closed gap).
  Reuses `UsageSessionRepository.fetchRecentForEmployees([myUid])` rather
  than adding a new repository method.
- `attendance_dashboard_controller.dart` / `attendance_dashboard_screen.dart`
  / `employee_attendance_screen.dart` — the team view (route
  `/team/attendance`, drill-down at `/team/attendance/detail`), scoped via
  `resolveVisibleEmployees` exactly like `VisitLogDashboardController`.
  Fetches the *same* `UsageSession` data the (separate) Usage Dashboard
  shows raw sessions from — this is a summary view of that data, not a
  second fetch path with its own caching/staleness story.

## Extending

A stricter attendance signal (e.g. requiring location, or a minimum
session duration to count as "present") only needs a change inside
`deriveAttendanceDays` — every screen here consumes its output, not raw
sessions directly, so the derivation logic has exactly one place to change.
