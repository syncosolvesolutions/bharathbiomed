import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import 'my_attendance_controller.dart';

/// The signed-in MR's own day-by-day attendance, derived from their app
/// open/close sessions — see [deriveAttendanceDays]. Read-only: there's
/// nothing to edit here, this just answers "was I marked present, and
/// when did I check in/out" for each day the app has a record of.
class MyAttendanceScreen extends ConsumerWidget {
  const MyAttendanceScreen({super.key});

  static String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(myAttendanceControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myAttendanceControllerProvider.notifier).refresh(),
        child: daysAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load attendance: ${UserFacingError.describe(error)}')),
          data: (days) {
            if (days.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No recorded days yet.\nAttendance is derived from app usage — it fills in as you use the app and sync.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(day.date),
                    subtitle: Text('In: ${_formatTime(day.firstCheckIn)}  •  Out: ${_formatTime(day.lastCheckOut)}'
                        '\n${day.sessionCount} session${day.sessionCount == 1 ? '' : 's'}'),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
