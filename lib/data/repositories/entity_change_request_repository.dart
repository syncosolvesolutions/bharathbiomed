import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/agency.dart';
import '../../domain/models/entity_change_request.dart';
import '../../domain/models/pharmacy.dart';
import '../local/entity_change_request_local_data_source.dart';
import '../remote/entity_change_request_remote_data_source.dart';

/// An MR's proposed agency/pharmacy creation, offline-first: [submitCreate]
/// only ever touches the local queue (works standing in the field with no
/// signal); [uploadPending] is what the sync pipeline calls to actually
/// reach Firestore. Mirrors [DoctorChangeRequestRepository].
class EntityChangeRequestRepository {
  EntityChangeRequestRepository({
    EntityChangeRequestRemoteDataSource? remote,
    EntityChangeRequestLocalDataSource? local,
  })  : _remote = remote ?? EntityChangeRequestRemoteDataSource(),
        _local = local ?? EntityChangeRequestLocalDataSource();

  final EntityChangeRequestRemoteDataSource _remote;
  final EntityChangeRequestLocalDataSource _local;

  Future<void> submitAgency(Agency proposed, {required String requestedByUid, required String requestedByName}) {
    debugPrint('EntityChangeRequestRepository.submitAgency: name=${proposed.name}');
    return _queue(
      entityType: EntityType.agency,
      proposedData: proposed.toJson()..remove('id'),
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
    );
  }

  Future<void> submitPharmacy(Pharmacy proposed, {required String requestedByUid, required String requestedByName}) {
    debugPrint('EntityChangeRequestRepository.submitPharmacy: name=${proposed.name}');
    return _queue(
      entityType: EntityType.pharmacy,
      proposedData: proposed.toJson()..remove('id'),
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
    );
  }

  Future<void> _queue({
    required EntityType entityType,
    required Map<String, dynamic> proposedData,
    required String requestedByUid,
    required String requestedByName,
  }) async {
    final localId = const Uuid().v4();
    await _local.insert(localId, {
      'entityType': entityTypeToJson(entityType),
      'type': 'create',
      'entityId': null,
      'proposedData': proposedData,
      'requestedByUid': requestedByUid,
      'requestedByName': requestedByName,
      'status': 'pending',
    });
    debugPrint('EntityChangeRequestRepository._queue: queued localId=$localId entityType=$entityType');
  }

  Future<int> countPendingUpload() => _local.countUnsynced();

  /// Best-effort, called from the sync pipeline — never lets a partial
  /// failure lose already-queued requests (they just stay queued for the
  /// next sync attempt).
  Future<void> uploadPending() async {
    debugPrint('EntityChangeRequestRepository.uploadPending: checking for unsynced requests');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('EntityChangeRequestRepository.uploadPending: nothing to upload');
      return;
    }
    debugPrint('EntityChangeRequestRepository.uploadPending: uploading ${pending.length} requests');
    final uploaded = <String>[];
    for (final request in pending) {
      try {
        await _remote.create(request.localId, {...request.data, 'createdAt': FieldValue.serverTimestamp()});
        uploaded.add(request.localId);
      } catch (error) {
        debugPrint('EntityChangeRequestRepository.uploadPending: failed localId=${request.localId} error=$error');
      }
    }
    await _local.markSynced(uploaded);
    debugPrint('EntityChangeRequestRepository.uploadPending: uploaded ${uploaded.length}/${pending.length}');
  }

  Future<List<EntityChangeRequest>> fetchPending() => _remote.fetchPending();

  Future<List<EntityChangeRequest>> fetchMine(String requestedByUid) => _remote.fetchMine(requestedByUid);

  Future<void> review(String requestId, {required bool approve, String? reviewNote}) =>
      _remote.review(requestId, approve: approve, reviewNote: reviewNote);
}
