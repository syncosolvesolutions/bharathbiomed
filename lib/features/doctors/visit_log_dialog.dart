import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/date_of_birth.dart';
import '../../data/providers.dart';
import '../../domain/models/doctor.dart';
import '../auth/auth_controller.dart';
import '../tracking/location_service.dart';

class _SampleRow {
  _SampleRow() : nameController = TextEditingController(), countController = TextEditingController(text: '1');

  final TextEditingController nameController;
  final TextEditingController countController;
}

/// Requirement 7: "MR should update daily which doctors he visited and their
/// feedback or today's visit update". Shown from both the doctor detail
/// screen and the Today's Visits screen so there's one place this logic
/// lives. Writes straight to the local queue (see
/// [DoctorVisitLogRepository.logVisit]) — no network required. Also records
/// any physician samples/promotional material given during the visit (see
/// [DoctorVisitLog.samplesGiven]) — tracked here rather than as a separate
/// feature since samples are given during a visit in practice.
Future<void> showVisitLogDialog(BuildContext context, WidgetRef ref, Doctor doctor, {String? visitDate}) async {
  final feedbackController = TextEditingController();
  final sampleRows = <_SampleRow>[];
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
              final samplesGiven = <String, int>{};
              for (final row in sampleRows) {
                final name = row.nameController.text.trim();
                final count = int.tryParse(row.countController.text.trim()) ?? 0;
                if (name.isNotEmpty && count > 0) samplesGiven[name] = count;
              }
              await ref.read(doctorVisitLogRepositoryProvider).logVisit(
                    mrUid: uid,
                    doctorId: doctor.id,
                    doctorName: doctor.name,
                    visitDate: visitDate ?? isoFromDate(DateTime.now()),
                    visited: visited,
                    feedback: feedbackController.text.trim(),
                    latitude: position?.latitude,
                    longitude: position?.longitude,
                    samplesGiven: samplesGiven,
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
            content: SingleChildScrollView(
              child: Column(
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Samples / gifts given', style: Theme.of(context).textTheme.titleSmall),
                      TextButton.icon(
                        onPressed: saving ? null : () => setState(() => sampleRows.add(_SampleRow())),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  ...sampleRows.map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: row.nameController,
                                decoration: const InputDecoration(labelText: 'Item name', isDense: true),
                                enabled: !saving,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: row.countController,
                                decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                                keyboardType: TextInputType.number,
                                enabled: !saving,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: saving ? null : () => setState(() => sampleRows.remove(row)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
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
