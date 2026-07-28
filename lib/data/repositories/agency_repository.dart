import 'package:flutter/foundation.dart';

import '../../domain/models/agency.dart';
import '../local/agency_local_data_source.dart';
import '../remote/agency_remote_data_source.dart';

/// Agencies, offline-first like [DoctorRepository]: [loadCached] is the only
/// thing agency list screens read from directly; [sync] is the one place
/// that talks to Firestore. Every signed-in user sees every agency (no
/// per-MR scoping, unlike doctors).
class AgencyRepository {
  AgencyRepository({AgencyRemoteDataSource? remote, AgencyLocalDataSource? local})
      : _remote = remote ?? AgencyRemoteDataSource(),
        _local = local ?? AgencyLocalDataSource();

  final AgencyRemoteDataSource _remote;
  final AgencyLocalDataSource _local;

  Future<List<Agency>> loadCached() {
    debugPrint('AgencyRepository.loadCached: loading agencies from local cache');
    return _local.getAgencies();
  }

  Future<List<Agency>> sync() async {
    debugPrint('AgencyRepository.sync: fetching agencies from remote');
    final agencies = await _remote.fetchAll();
    await _local.replaceAll(agencies);
    return agencies;
  }

  /// Fetches the remote agency list and diffs it against the local cache
  /// instead of overwriting it — see
  /// [ProductRepository.hasRemoteChanges] for why this pattern is used.
  Future<bool> hasRemoteChanges() async {
    debugPrint('AgencyRepository.hasRemoteChanges: fetching remote agencies to diff against local cache');
    final remote = await _remote.fetchAll();
    final local = await _local.getAgencies();
    final remoteById = {for (final agency in remote) agency.id: agency};
    final localById = {for (final agency in local) agency.id: agency};
    final changed = !mapEquals(remoteById, localById);
    debugPrint('AgencyRepository.hasRemoteChanges: changed=$changed');
    return changed;
  }

  /// Office-Admin-only in firestore.rules.
  Future<String> createAgency(Agency agency) {
    debugPrint('AgencyRepository.createAgency: name=${agency.name}');
    return _remote.addAgency(agency);
  }

  /// Office Admin, or anyone holding `manage_agencies`, per firestore.rules.
  Future<void> updateAgency(Agency agency) {
    debugPrint('AgencyRepository.updateAgency: id=${agency.id}');
    return _remote.updateAgency(agency);
  }

  /// Office-Admin-only in firestore.rules.
  Future<void> setActive(String id, {required bool active}) {
    debugPrint('AgencyRepository.setActive: id=$id active=$active');
    return _remote.setActive(id, active: active);
  }
}
