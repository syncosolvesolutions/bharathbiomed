import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Which kind of entity this request proposes a create/update for. Shared
/// mechanism for [Agency] and [Pharmacy] — both need the identical
/// MR-proposes/Office-Admin-reviews shape [DoctorChangeRequest] already has
/// for doctors, so rather than duplicate that model twice more, one generic
/// request type covers both, disambiguated by [entityType].
enum EntityType { agency, pharmacy }

enum EntityChangeType { create, update }

enum EntityChangeStatus { pending, approved, rejected }

EntityType entityTypeFromString(String? value) => value == 'pharmacy' ? EntityType.pharmacy : EntityType.agency;

String entityTypeToJson(EntityType type) => type == EntityType.pharmacy ? 'pharmacy' : 'agency';

EntityChangeType entityChangeTypeFromString(String? value) =>
    value == 'update' ? EntityChangeType.update : EntityChangeType.create;

EntityChangeStatus entityChangeStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return EntityChangeStatus.approved;
    case 'rejected':
      return EntityChangeStatus.rejected;
    default:
      return EntityChangeStatus.pending;
  }
}

/// An MR's proposed agency/pharmacy creation, awaiting Office Admin review.
/// [proposedData] mirrors that entity's `toJson()` — approving it is just
/// writing that map straight into `Agencies`/`Pharmacies`. See
/// `reviewEntityChangeRequest` (Cloud Function) for how approval is applied,
/// and [DoctorChangeRequest] for the pattern this mirrors.
class EntityChangeRequest extends Equatable {
  final String id;
  final EntityType entityType;
  final EntityChangeType type;

  /// Null for a `create` request; the existing entity's id for `update`.
  final String? entityId;
  final Map<String, dynamic> proposedData;
  final String requestedByUid;
  final String requestedByName;
  final EntityChangeStatus status;
  final String? reviewNote;
  final String? reviewedByUid;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  const EntityChangeRequest({
    required this.id,
    required this.entityType,
    required this.type,
    this.entityId,
    required this.proposedData,
    required this.requestedByUid,
    required this.requestedByName,
    this.status = EntityChangeStatus.pending,
    this.reviewNote,
    this.reviewedByUid,
    this.reviewedAt,
    this.createdAt,
  });

  /// What the request proposes to name the entity, for display in the
  /// review list without looking up the underlying entity separately.
  String get entityName => proposedData['name'] as String? ?? '(unnamed)';

  factory EntityChangeRequest.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('EntityChangeRequest.fromJson: parsing request id=$id');
    return EntityChangeRequest(
      id: id,
      entityType: entityTypeFromString(json['entityType'] as String?),
      type: entityChangeTypeFromString(json['type'] as String?),
      entityId: json['entityId'] as String?,
      proposedData: Map<String, dynamic>.from(json['proposedData'] as Map? ?? const {}),
      requestedByUid: json['requestedByUid'] as String? ?? '',
      requestedByName: json['requestedByName'] as String? ?? '',
      status: entityChangeStatusFromString(json['status'] as String?),
      reviewNote: json['reviewNote'] as String?,
      reviewedByUid: json['reviewedByUid'] as String?,
      reviewedAt: (json['reviewedAt'] as Timestamp?)?.toDate(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'entityType': entityTypeToJson(entityType),
      'type': type == EntityChangeType.update ? 'update' : 'create',
      'entityId': entityId,
      'proposedData': proposedData,
      'requestedByUid': requestedByUid,
      'requestedByName': requestedByName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        entityType,
        type,
        entityId,
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
