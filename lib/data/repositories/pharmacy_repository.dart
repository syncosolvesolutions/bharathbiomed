import 'package:flutter/foundation.dart';

import '../../domain/models/pharmacy.dart';
import '../local/pharmacy_local_data_source.dart';
import '../remote/pharmacy_remote_data_source.dart';

/// Pharmacies, offline-first — mirrors [AgencyRepository] exactly.
class PharmacyRepository {
  PharmacyRepository({PharmacyRemoteDataSource? remote, PharmacyLocalDataSource? local})
      : _remote = remote ?? PharmacyRemoteDataSource(),
        _local = local ?? PharmacyLocalDataSource();

  final PharmacyRemoteDataSource _remote;
  final PharmacyLocalDataSource _local;

  Future<List<Pharmacy>> loadCached() {
    debugPrint('PharmacyRepository.loadCached: loading pharmacies from local cache');
    return _local.getPharmacies();
  }

  Future<List<Pharmacy>> sync() async {
    debugPrint('PharmacyRepository.sync: fetching pharmacies from remote');
    final pharmacies = await _remote.fetchAll();
    await _local.replaceAll(pharmacies);
    return pharmacies;
  }

  /// Mirrors [AgencyRepository.hasRemoteChanges].
  Future<bool> hasRemoteChanges() async {
    debugPrint('PharmacyRepository.hasRemoteChanges: fetching remote pharmacies to diff against local cache');
    final remote = await _remote.fetchAll();
    final local = await _local.getPharmacies();
    final remoteById = {for (final pharmacy in remote) pharmacy.id: pharmacy};
    final localById = {for (final pharmacy in local) pharmacy.id: pharmacy};
    final changed = !mapEquals(remoteById, localById);
    debugPrint('PharmacyRepository.hasRemoteChanges: changed=$changed');
    return changed;
  }

  Future<String> createPharmacy(Pharmacy pharmacy) {
    debugPrint('PharmacyRepository.createPharmacy: name=${pharmacy.name}');
    return _remote.addPharmacy(pharmacy);
  }

  Future<void> updatePharmacy(Pharmacy pharmacy) {
    debugPrint('PharmacyRepository.updatePharmacy: id=${pharmacy.id}');
    return _remote.updatePharmacy(pharmacy);
  }

  Future<void> setActive(String id, {required bool active}) {
    debugPrint('PharmacyRepository.setActive: id=$id active=$active');
    return _remote.setActive(id, active: active);
  }

  /// Every cached pharmacy linked to [doctorId] — computed client-side over
  /// the local cache rather than a live query, so the doctor detail screen
  /// stays offline-friendly (mirrors this app's general "read from local
  /// cache, sync explicitly" philosophy).
  Future<List<Pharmacy>> loadLinkedToDoctor(String doctorId) async {
    final all = await loadCached();
    return all.where((pharmacy) => pharmacy.linkedDoctorIds.contains(doctorId)).toList();
  }
}
