import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'doctor.dart';

enum DoctorChangeType { create, update }

enum DoctorChangeStatus { pending, approved, rejected }

DoctorChangeType doctorChangeTypeFromString(String? value) =>
    value == 'update' ? DoctorChangeType.update : DoctorChangeType.create;

DoctorChangeStatus doctorChangeStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return DoctorChangeStatus.approved;
    case 'rejected':
      return DoctorChangeStatus.rejected;
    default:
      return DoctorChangeStatus.pending;
  }
}

/// An MR's proposed doctor creation/edit, awaiting admin approval (see
/// requirement 4/5: "MR also can update Doctors info but before its
/// publication admin needs to approve"). [proposedData] mirrors
/// [Doctor.toJson] — everything the MR filled in for the new/edited doctor —
/// so approving it is just writing that map straight into `Doctors`.
class DoctorChangeRequest extends Equatable {
  final String id;
  final DoctorChangeType type;

  /// Null for a `create` request; the existing doctor's id for `update`.
  final String? doctorId;
  final Map<String, dynamic> proposedData;
  final String requestedByUid;
  final String requestedByName;
  final DoctorChangeStatus status;
  final String? reviewNote;
  final String? reviewedByUid;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  const DoctorChangeRequest({
    required this.id,
    required this.type,
    this.doctorId,
    required this.proposedData,
    required this.requestedByUid,
    required this.requestedByName,
    this.status = DoctorChangeStatus.pending,
    this.reviewNote,
    this.reviewedByUid,
    this.reviewedAt,
    this.createdAt,
  });

  /// What the request is proposing to name the doctor / hospital, for
  /// display in the admin's requests list without needing to look up the
  /// underlying doctor separately.
  String get doctorName => proposedData['name'] as String? ?? '(unnamed)';
  String get hospitalName => proposedData['hospitalName'] as String? ?? '';

  factory DoctorChangeRequest.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('DoctorChangeRequest.fromJson: parsing request id=$id');
    return DoctorChangeRequest(
      id: id,
      type: doctorChangeTypeFromString(json['type'] as String?),
      doctorId: json['doctorId'] as String?,
      proposedData: Map<String, dynamic>.from(json['proposedData'] as Map? ?? const {}),
      requestedByUid: json['requestedByUid'] as String? ?? '',
      requestedByName: json['requestedByName'] as String? ?? '',
      status: doctorChangeStatusFromString(json['status'] as String?),
      reviewNote: json['reviewNote'] as String?,
      reviewedByUid: json['reviewedByUid'] as String?,
      reviewedAt: (json['reviewedAt'] as Timestamp?)?.toDate(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'type': type == DoctorChangeType.update ? 'update' : 'create',
      'doctorId': doctorId,
      'proposedData': proposedData,
      'requestedByUid': requestedByUid,
      'requestedByName': requestedByName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Turns a [Doctor] into what this doctor would look like once serialized
  /// for the local pending-request queue, so it can be reconstructed and
  /// uploaded later even if the app is killed before it syncs.
  static Map<String, dynamic> proposedDataFromDoctor(Doctor doctor) => doctor.toJson()..remove('id');

  @override
  List<Object?> get props => [
        id,
        type,
        doctorId,
        proposedData,
        requestedByUid,
        requestedByName,
        status,
        reviewNote,
        reviewedByUid,
        reviewedAt,
        createdAt,
      ];
}
