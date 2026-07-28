import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/doctor.dart';
import '../admin/admin_access.dart';
import '../auth/auth_controller.dart';

/// Holds the doctor list currently shown on screen — an MR's assigned
/// doctors, or (for the admin) every doctor. Offline-first like
/// [CatalogController]: [build] only ever reads the local cache; [sync] is
/// the one place that talks to Firestore.
final doctorControllerProvider = AsyncNotifierProvider<DoctorController, List<Doctor>>(DoctorController.new);

class DoctorController extends AsyncNotifier<List<Doctor>> {
  @override
  Future<List<Doctor>> build() {
    debugPrint('DoctorController.build: loading cached doctors');
    return ref.read(doctorRepositoryProvider).loadCached();
  }

  /// `null` for the admin (fetch every doctor); the signed-in MR's uid
  /// otherwise (fetch only doctors assigned to them).
  String? get _scopeMrUid {
    if (ref.read(isAdminProvider)) return null;
    return ref.read(authControllerProvider).value?.uid;
  }

  Future<void> sync() async {
    debugPrint('DoctorController.sync: starting doctor sync with Firestore');
    final doctors = await ref.read(doctorRepositoryProvider).sync(mrUid: _scopeMrUid);
    debugPrint('DoctorController.sync: doctor sync succeeded, ${doctors.length} doctors');
    state = AsyncData(doctors);
  }

  Future<void> refreshFromCache() async {
    state = await AsyncValue.guard(() => ref.read(doctorRepositoryProvider).loadCached());
  }
}
