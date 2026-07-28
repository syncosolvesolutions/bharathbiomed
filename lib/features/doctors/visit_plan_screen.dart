import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/user_facing_error.dart';
import '../../domain/models/doctor_visit_plan.dart';
import 'doctor_controller.dart';
import 'doctor_visit_plan_controller.dart';

/// Weekly recurring visiting schedule editor (requirement 13/14): one tab per
/// weekday, each listing the MR's assigned doctors with a checkbox for
/// whether they're planned for that day. A doctor can be checked on more
/// than one day.
class VisitPlanScreen extends ConsumerWidget {
  const VisitPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsAsync = ref.watch(doctorControllerProvider);
    final planAsync = ref.watch(doctorVisitPlanControllerProvider);

    return DefaultTabController(
      length: weekdayKeys.length,
      initialIndex: DateTime.now().weekday - 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Weekly Visit Plan'),
          bottom: TabBar(
            isScrollable: true,
            tabs: weekdayLabels.map((label) => Tab(text: label)).toList(),
          ),
        ),
        body: doctorsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load doctors: ${UserFacingError.describe(error)}')),
          data: (doctors) {
            if (doctors.isEmpty) {
              return const Center(child: Text('No doctors assigned yet — add or wait for assignment first.'));
            }
            return planAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load plan: ${UserFacingError.describe(error)}')),
              data: (plan) => TabBarView(
                children: weekdayKeys.map((weekdayKey) {
                  final selected = plan.forWeekday(weekdayKey).toSet();
                  return ListView.builder(
                    itemCount: doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return CheckboxListTile(
                        title: Text(doctor.name),
                        subtitle: Text(doctor.hospitalName),
                        value: selected.contains(doctor.id),
                        onChanged: (_) =>
                            ref.read(doctorVisitPlanControllerProvider.notifier).toggleDoctor(weekdayKey, doctor.id),
                      );
                    },
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
