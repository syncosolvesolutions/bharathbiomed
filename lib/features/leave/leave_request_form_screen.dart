import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../data/providers.dart';
import '../../domain/models/leave_request.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_controller.dart';
import 'my_leave_requests_controller.dart';

/// File a leave request: type, date range, optional reason. Offline-first
/// — [_save] queues it locally; it reaches Firestore on the next sync.
class LeaveRequestFormScreen extends ConsumerStatefulWidget {
  const LeaveRequestFormScreen({super.key});

  @override
  ConsumerState<LeaveRequestFormScreen> createState() => _LeaveRequestFormScreenState();
}

class _LeaveRequestFormScreenState extends ConsumerState<LeaveRequestFormScreen> {
  LeaveType _leaveType = LeaveType.casual;
  DateTimeRange _range = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  final _reasonController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _range = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = ref.read(authControllerProvider).value?.uid ?? '';
      final myName = ref.read(myEmployeeProfileProvider).value?.displayName ?? '';
      final request = LeaveRequest(
        id: const Uuid().v4(),
        mrUid: uid,
        mrName: myName,
        leaveType: _leaveType,
        startDate: isoFromDate(_range.start),
        endDate: isoFromDate(_range.end),
        reason: _reasonController.text.trim(),
      );
      await ref.read(leaveRequestRepositoryProvider).submit(request);
      ref.invalidate(myLeaveRequestsControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Leave request queued — will upload on next sync.')));
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AppLogger.error('LeaveRequestForm', 'save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Failed to save request',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sameDay = isoFromDate(_range.start) == isoFromDate(_range.end);
    return Scaffold(
      appBar: AppBar(title: const Text('Request Leave')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            DropdownButtonFormField<LeaveType>(
              initialValue: _leaveType,
              decoration: const InputDecoration(labelText: 'Leave Type'),
              items: LeaveType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.label))).toList(),
              onChanged: (type) => setState(() => _leaveType = type ?? _leaveType),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickRange,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Dates'),
                child: Row(children: [
                  Expanded(
                    child: Text(sameDay
                        ? formatIsoForDisplay(isoFromDate(_range.start))
                        : '${formatIsoForDisplay(isoFromDate(_range.start))} — '
                            '${formatIsoForDisplay(isoFromDate(_range.end))}'),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }
}
