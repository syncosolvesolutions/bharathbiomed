import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../data/providers.dart';
import '../../domain/models/doctor.dart';
import '../../domain/models/doctor_visit_log.dart';
import '../../domain/models/doctor_visit_plan.dart';
import '../auth/auth_controller.dart';
import 'doctor_controller.dart';
import 'doctor_visit_plan_controller.dart';
import 'visit_log_dialog.dart';

/// Requirement 6/13: "MR should see his doctors list and today plan if
/// created if not option to create plan". Shows today's weekday's planned
/// doctors (from the recurring [DoctorVisitPlan]) alongside whether each has
/// already been logged today, plus a way to log an ad-hoc visit for an
/// assigned doctor who isn't on today's plan.
class TodayVisitsScreen extends ConsumerStatefulWidget {
  const TodayVisitsScreen({super.key});

  @override
  ConsumerState<TodayVisitsScreen> createState() => _TodayVisitsScreenState();
}

class _TodayVisitsScreenState extends ConsumerState<TodayVisitsScreen> {
  List<DoctorVisitLog> _todaysLogs = [];
  bool _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    final uid = ref.read(authControllerProvider).value?.uid ?? '';
    final today = isoFromDate(DateTime.now());
    final logs = await ref.read(doctorVisitLogRepositoryProvider).loadForMr(uid);
    if (!mounted) return;
    setState(() {
      _todaysLogs = logs.where((log) => log.visitDate == today).toList();
      _loadingLogs = false;
    });
  }

  Future<void> _logVisit(Doctor doctor) async {
    await showVisitLogDialog(context, ref, doctor);
    await _loadLogs();
  }

  Future<void> _addAdHocVisit(List<Doctor> doctors, Set<String> plannedIds) async {
    final available = doctors.where((doctor) => !plannedIds.contains(doctor.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Every assigned doctor is already on today\'s plan.')));
      return;
    }
    final chosen = await showDialog<Doctor>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Log a visit for another doctor'),
        children: available
            .map((doctor) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(doctor),
                  child: Text('${doctor.name} — ${doctor.hospitalName}'),
                ))
            .toList(),
      ),
    );
    if (chosen != null) await _logVisit(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(doctorControllerProvider);
    final planAsync = ref.watch(doctorVisitPlanControllerProvider);
    final todayLabel = weekdayLabels[DateTime.now().weekday - 1];
    final loggedDoctorIds = _todaysLogs.map((log) => log.doctorId).toSet();

    return Scaffold(
      appBar: AppBar(title: Text("Today's Visits — $todayLabel")),
      body: doctorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load doctors: ${UserFacingError.describe(error)}')),
        data: (doctors) => planAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load plan: ${UserFacingError.describe(error)}')),
          data: (plan) {
            final plannedIds = plan.forToday.toSet();
            final plannedDoctors = doctors.where((doctor) => plannedIds.contains(doctor.id)).toList();

            if (plannedDoctors.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No plan for today yet.', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.push('/doctors/plan'),
                      child: const Text('Create Weekly Plan'),
                    ),
                    if (doctors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadingLogs ? null : () => _addAdHocVisit(doctors, plannedIds),
                        child: const Text('Log a visit anyway'),
                      ),
                    ],
                  ],
                ),
              );
            }

            return _loadingLogs
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: plannedDoctors.length + 1,
                    itemBuilder: (context, index) {
                      if (index == plannedDoctors.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton.icon(
                            onPressed: () => _addAdHocVisit(doctors, plannedIds),
                            icon: const Icon(Icons.add),
                            label: const Text('Log a visit for another doctor'),
                          ),
                        );
                      }
                      final doctor = plannedDoctors[index];
                      final logged = loggedDoctorIds.contains(doctor.id);
                      return ListTile(
                        title: Text(doctor.name),
                        subtitle: Text(doctor.hospitalName),
                        trailing: logged
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : OutlinedButton(onPressed: () => _logVisit(doctor), child: const Text('Log Visit')),
                      );
                    },
                  );
          },
        ),
      ),
    );
  }
}
