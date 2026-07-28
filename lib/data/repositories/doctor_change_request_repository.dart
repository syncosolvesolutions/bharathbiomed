import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/doctor.dart';
import '../../domain/models/doctor_change_request.dart';
import '../local/doctor_change_request_local_data_source.dart';
import '../remote/doctor_change_request_remote_data_source.dart';

/// An MR's doctor create/edit proposals, offline-first: [submitCreate] and
/// [submitUpdate] only ever touch the local queue (so they work standing in
/// a hospital with no signal — requirement 9/11); [uploadPending] is what the
/// evening sync calls to actually reach Firestore. The admin side
/// ([fetchPending]/[review]) always talks to Firestore directly since the
/// admin reviewing requests is assumed to be online.
class DoctorChangeRequestRepository {
  DoctorChangeRequestRepository({
    DoctorChangeRequestRemoteDataSource? remote,
    DoctorChangeRequestLocalDataSource? local,
  })  : _remote = remote ?? DoctorChangeRequestRemoteDataSource(),
        _local = local ?? DoctorChangeRequestLocalDataSource();

  final DoctorChangeRequestRemoteDataSource _remote;
  final DoctorChangeRequestLocalDataSource _local;

  Future<void> submitCreate(Doctor proposed, {required String requestedByUid, required String requestedByName}) {
    debugPrint('DoctorChangeRequestRepository.submitCreate: name=${proposed.name}');
    return _queue(
      type: DoctorChangeType.create,
      doctorId: null,
      proposedData: DoctorChangeRequest.proposedDataFromDoctor(proposed),
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
    );
  }

  Future<void> submitUpdate(Doctor proposed, {required String requestedByUid, required String requestedByName}) {
    debugPrint('DoctorChangeRequestRepository.submitUpdate: doctorId=${proposed.id}');
    return _queue(
      type: DoctorChangeType.update,
      doctorId: proposed.id,
      proposedData: DoctorChangeRequest.proposedDataFromDoctor(proposed),
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
    );
  }

  Future<void> _queue({
    required DoctorChangeType type,
    required String? doctorId,
    required Map<String, dynamic> proposedData,
    required String requestedByUid,
    required String requestedByName,
  }) async {
    final localId = const Uuid().v4();
    await _local.insert(localId, {
      'type': type == DoctorChangeType.update ? 'update' : 'create',
      'doctorId': doctorId,
      'proposedData': proposedData,
      'requestedByUid': requestedByUid,
      'requestedByName': requestedByName,
      'status': 'pending',
    });
    debugPrint('DoctorChangeRequestRepository._queue: queued localId=$localId');
  }

  Future<int> countPendingUpload() => _local.countUnsynced();

  /// Best-effort, called from the evening sync — never lets a partial
  /// failure lose already-queued requests (they just stay queued for the
  /// next sync attempt).
  Future<void> uploadPending() async {
    debugPrint('DoctorChangeRequestRepository.uploadPending: checking for unsynced requests');
    final pending = await _local.getUnsynced();
    if (pending.isEmpty) {
      debugPrint('DoctorChangeRequestRepository.uploadPending: nothing to upload');
      return;
    }
    debugPrint('DoctorChangeRequestRepository.uploadPending: uploading ${pending.length} requests');
    final uploaded = <String>[];
    for (final request in pending) {
      try {
        await _remote.create(request.localId, {...request.data, 'createdAt': FieldValue.serverTimestamp()});
        uploaded.add(request.localId);
      } catch (error) {
        debugPrint(
            'DoctorChangeRequestRepository.uploadPending: failed to upload localId=${request.localId} error=$error');
        // Leave it queued — the next sync attempt will retry it.
      }
    }
    await _local.markSynced(uploaded);
    debugPrint('DoctorChangeRequestRepository.uploadPending: uploaded ${uploaded.length}/${pending.length}');
  }

  Future<List<DoctorChangeRequest>> fetchPending() => _remote.fetchPending();

  Future<List<DoctorChangeRequest>> fetchMine(String requestedByUid) => _remote.fetchMine(requestedByUid);

  Future<void> review(String requestId, {required bool approve, String? reviewNote}) =>
      _remote.review(requestId, approve: approve, reviewNote: reviewNote);
}
