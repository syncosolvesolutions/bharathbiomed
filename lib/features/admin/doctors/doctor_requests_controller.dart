import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/models/doctor_change_request.dart';
import '../../doctors/doctor_controller.dart';

/// Pending doctor create/edit requests awaiting the admin's review
/// (requirement 4/5). Always talks to Firestore directly — the admin
/// reviewing requests is assumed to be online.
final doctorRequestsControllerProvider =
    AsyncNotifierProvider<DoctorRequestsController, List<DoctorChangeRequest>>(DoctorRequestsController.new);

class DoctorRequestsController extends AsyncNotifier<List<DoctorChangeRequest>> {
  @override
  Future<List<DoctorChangeRequest>> build() {
    debugPrint('DoctorRequestsController.build: fetching pending requests');
    return ref.read(doctorChangeRequestRepositoryProvider).fetchPending();
  }

  Future<void> review(String requestId, {required bool approve, String? reviewNote}) async {
    debugPrint('DoctorRequestsController.review: requestId=$requestId approve=$approve');
    await ref.read(doctorChangeRequestRepositoryProvider).review(requestId, approve: approve, reviewNote: reviewNote);
    state = await AsyncValue.guard(() => ref.read(doctorChangeRequestRepositoryProvider).fetchPending());
    // An approval just changed what's in `Doctors` — keep the admin's
    // doctor list from looking stale if they navigate back to it next.
    await ref.read(doctorControllerProvider.notifier).sync();
  }
}
