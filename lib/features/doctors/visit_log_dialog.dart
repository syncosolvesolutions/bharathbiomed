import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../data/providers.dart';
import '../../domain/models/doctor.dart';
import '../auth/auth_controller.dart';
import '../tracking/location_service.dart';

/// Requirement 7: "MR should update daily which doctors he visited and their
/// feedback or today's visit update". Shown from both the doctor detail
/// screen and the Today's Visits screen so there's one place this logic
/// lives. Writes straight to the local queue (see
/// [DoctorVisitLogRepository.logVisit]) — no network required.
Future<void> showVisitLogDialog(BuildContext context, WidgetRef ref, Doctor doctor, {String? visitDate}) async {
  final feedbackController = TextEditingController();
  bool visited = true;
  bool saving = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> save() async {
            setState(() => saving = true);
            try {
              final uid = ref.read(authControllerProvider).value?.uid ?? '';
              final position = await LocationService().getCurrentLocationBestEffort();
              await ref.read(doctorVisitLogRepositoryProvider).logVisit(
                    mrUid: uid,
                    doctorId: doctor.id,
                    doctorName: doctor.name,
                    visitDate: visitDate ?? isoFromDate(DateTime.now()),
                    visited: visited,
                    feedback: feedbackController.text.trim(),
                    latitude: position?.latitude,
                    longitude: position?.longitude,
                  );
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Visit saved locally — it will upload on your next sync.')));
            } catch (error, stackTrace) {
              AppLogger.error('VisitLogDialog', 'logVisit failed', error: error, stackTrace: stackTrace);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Failed to save visit: ${UserFacingError.describe(error)}')));
            } finally {
              if (context.mounted) setState(() => saving = false);
            }
          }

          return AlertDialog(
            title: Text('Log visit — ${doctor.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Visited'),
                  value: visited,
                  onChanged: saving ? null : (value) => setState(() => visited = value),
                ),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(labelText: 'Feedback / notes'),
                  maxLines: 3,
                  enabled: !saving,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
