import 'package:bharathbiomedpharma/domain/models/usage_session.dart';
import 'package:bharathbiomedpharma/features/attendance/attendance_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deriveAttendanceDays', () {
    test('groups multiple sessions on the same day into one AttendanceDay', () {
      final sessions = [
        UsageSession(
          id: '1',
          employeeUid: 'mr1',
          username: 'rajesh',
          openedAt: DateTime(2026, 7, 29, 9, 0),
          closedAt: DateTime(2026, 7, 29, 11, 0),
        ),
        UsageSession(
          id: '2',
          employeeUid: 'mr1',
          username: 'rajesh',
          openedAt: DateTime(2026, 7, 29, 14, 0),
          closedAt: DateTime(2026, 7, 29, 17, 30),
          latitude: 19.07,
          longitude: 72.87,
        ),
      ];

      final days = deriveAttendanceDays(sessions);

      expect(days, hasLength(1));
      expect(days.single.date, '2026-07-29');
      expect(days.single.firstCheckIn, DateTime(2026, 7, 29, 9, 0));
      expect(days.single.lastCheckOut, DateTime(2026, 7, 29, 17, 30));
      expect(days.single.sessionCount, 2);
      expect(days.single.hasLocation, isTrue);
    });

    test('falls back to openedAt for a session that was never closed', () {
      final sessions = [
        UsageSession(id: '1', employeeUid: 'mr1', username: 'rajesh', openedAt: DateTime(2026, 7, 29, 9, 0)),
      ];

      final days = deriveAttendanceDays(sessions);

      expect(days.single.lastCheckOut, DateTime(2026, 7, 29, 9, 0));
    });

    test('sorts most recent day first', () {
      final sessions = [
        UsageSession(id: '1', employeeUid: 'mr1', username: 'rajesh', openedAt: DateTime(2026, 7, 27, 9, 0)),
        UsageSession(id: '2', employeeUid: 'mr1', username: 'rajesh', openedAt: DateTime(2026, 7, 29, 9, 0)),
        UsageSession(id: '3', employeeUid: 'mr1', username: 'rajesh', openedAt: DateTime(2026, 7, 28, 9, 0)),
      ];

      final days = deriveAttendanceDays(sessions);

      expect(days.map((d) => d.date).toList(), ['2026-07-29', '2026-07-28', '2026-07-27']);
    });

    test('returns an empty list for no sessions', () {
      expect(deriveAttendanceDays([]), isEmpty);
    });
  });
}
