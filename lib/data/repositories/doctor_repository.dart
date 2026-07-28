import 'package:flutter/foundation.dart';

import '../../domain/models/doctor.dart';
import '../local/doctor_local_data_source.dart';
import '../remote/doctor_remote_data_source.dart';

/// Doctors, offline-first like [ProductRepository]: [loadCached] is the only
/// thing the doctor list screens read from directly; [sync] is the one place
/// that talks to Firestore, and overwrites the local cache with whatever the
/// signed-in user is allowed to see (an MR's assigned doctors, or — for the
/// admin — every doctor).
class DoctorRepository {
  DoctorRepository({DoctorRemoteDataSource? remote, DoctorLocalDataSource? local})
      : _remote = remote ?? DoctorRemoteDataSource(),
        _local = local ?? DoctorLocalDataSource();

  final DoctorRemoteDataSource _remote;
  final DoctorLocalDataSource _local;

  Future<bool> hasCachedDoctors() => _local.hasDoctors();

  Future<List<Doctor>> loadCached() {
    debugPrint('DoctorRepository.loadCached: loading doctors from local cache');
    return _local.getDoctors();
  }

  /// [mrUid] null means "admin: fetch every doctor"; non-null fetches only
  /// that MR's assigned doctors.
  Future<List<Doctor>> sync({String? mrUid}) async {
    debugPrint('DoctorRepository.sync: fetching doctors from remote mrUid=$mrUid');
    final doctors = mrUid == null ? await _remote.fetchAll() : await _remote.fetchAssignedTo(mrUid);
    debugPrint('DoctorRepository.sync: fetched ${doctors.length} doctors, replacing local cache');
    await _local.replaceAll(doctors);
    return doctors;
  }

  /// Fetches the remote doctor list (scoped the same way [sync] would be)
  /// and diffs it against the local cache instead of overwriting it — see
  /// [ProductRepository.hasRemoteChanges] for why this pattern is used
  /// instead of a cheaper metadata check.
  Future<bool> hasRemoteChanges({String? mrUid}) async {
    debugPrint('DoctorRepository.hasRemoteChanges: fetching remote doctors to diff against local cache mrUid=$mrUid');
    final remote = mrUid == null ? await _remote.fetchAll() : await _remote.fetchAssignedTo(mrUid);
    final local = await _local.getDoctors();
    final remoteById = {for (final doctor in remote) doctor.id: doctor};
    final localById = {for (final doctor in local) doctor.id: doctor};
    final changed = !mapEquals(remoteById, localById);
    debugPrint('DoctorRepository.hasRemoteChanges: changed=$changed');
    return changed;
  }

  /// Admin-only: creates a doctor outright (no approval needed — see
  /// requirement 1). Auto-assigns nobody unless [doctor.assignedMrUid] is set.
  Future<String> createDoctor(Doctor doctor) {
    debugPrint('DoctorRepository.createDoctor: name=${doctor.name}');
    return _remote.addDoctor(doctor);
  }

  Future<void> updateDoctor(Doctor doctor) {
    debugPrint('DoctorRepository.updateDoctor: id=${doctor.id}');
    return _remote.updateDoctor(doctor);
  }

  Future<void> assignMr(String doctorId, {required String? mrUid, required String? mrName}) {
    debugPrint('DoctorRepository.assignMr: doctorId=$doctorId mrUid=$mrUid');
    return _remote.assignMr(doctorId, mrUid: mrUid, mrName: mrName);
  }

  Future<void> deleteDoctor(String id) {
    debugPrint('DoctorRepository.deleteDoctor: id=$id');
    return _remote.deleteDoctor(id);
  }
}
