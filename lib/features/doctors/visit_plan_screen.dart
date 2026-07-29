import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../domain/models/doctor_visit_plan.dart';
import 'doctor_controller.dart';
import 'doctor_visit_plan_controller.dart';

/// Weekly recurring visiting schedule editor (requirement 13/14): one tab per
/// weekday, each listing the MR's assigned doctors with a checkbox for
/// whether they're planned for that day. A doctor can be checked on more
/// than one day.
///
/// Also where the MR submits this plan for manager approval — see
/// [VisitPlanStatus]. Content edits (the checkboxes) are blocked by
/// firestore.rules while a review is pending, so the checkboxes are
/// disabled in that state rather than letting an edit silently fail server-
/// side.
class VisitPlanScreen extends ConsumerStatefulWidget {
  const VisitPlanScreen({super.key});

  @override
  ConsumerState<VisitPlanScreen> createState() => _VisitPlanScreenState();
}

class _VisitPlanScreenState extends ConsumerState<VisitPlanScreen> {
  bool _submitting = false;

  Color _statusColor(VisitPlanStatus status) => switch (status) {
        VisitPlanStatus.draft => Colors.grey,
        VisitPlanStatus.pending => Colors.orange,
        VisitPlanStatus.approved => Colors.green,
        VisitPlanStatus.rejected => Colors.red,
      };

  String _statusLabel(VisitPlanStatus status) => switch (status) {
        VisitPlanStatus.draft => 'Not submitted',
        VisitPlanStatus.pending => 'Pending approval',
        VisitPlanStatus.approved => 'Approved',
        VisitPlanStatus.rejected => 'Rejected',
      };

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(doctorVisitPlanControllerProvider.notifier).submitForApproval();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for approval.')));
    } catch (error, stackTrace) {
      AppLogger.error('VisitPlanScreen', 'submitForApproval failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to submit: ${UserFacingError.describe(error)}')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(doctorControllerProvider);
    final planAsync = ref.watch(doctorVisitPlanControllerProvider);
    final plan = planAsync.value;
    final isPending = plan?.status == VisitPlanStatus.pending;

    return DefaultTabController(
      length: weekdayKeys.length,
      initialIndex: DateTime.now().weekday - 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Weekly Visit Plan'),
          actions: [
            if (plan != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Chip(
                  label: Text(_statusLabel(plan.status), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  backgroundColor: _statusColor(plan.status),
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
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
              data: (loadedPlan) => Column(
                children: [
                  if (loadedPlan.status == VisitPlanStatus.rejected &&
                      (loadedPlan.rejectedReason?.isNotEmpty ?? false))
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Rejected: ${loadedPlan.rejectedReason}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      children: weekdayKeys.map((weekdayKey) {
                        final selected = loadedPlan.forWeekday(weekdayKey).toSet();
                        return ListView.builder(
                          itemCount: doctors.length,
                          itemBuilder: (context, index) {
                            final doctor = doctors[index];
                            return CheckboxListTile(
                              title: Text(doctor.name),
                              subtitle: Text(doctor.hospitalName),
                              value: selected.contains(doctor.id),
                              onChanged: isPending
                                  ? null
                                  : (_) => ref
                                      .read(doctorVisitPlanControllerProvider.notifier)
                                      .toggleDoctor(weekdayKey, doctor.id),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        floatingActionButton: isPending
            ? null
            : FloatingActionButton.extended(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined),
                label: const Text('Submit for Approval'),
              ),
      ),
    );
  }
}
