import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A pharmacy/chemist outlet — where RCPA audits happen and where stock an
/// agency supplies ultimately ends up. [linkedDoctorIds] maps this pharmacy
/// to the doctor(s) it's associated with (e.g. next to a doctor's clinic, or
/// where a doctor's patients are known to fill prescriptions), surfaced in
/// reverse on the doctor detail screen. Created directly only by an Office
/// Admin; an MR proposes a new one via [EntityChangeRequest] instead — same
/// rules as [Agency].
class Pharmacy extends Equatable {
  final String id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final List<String> linkedDoctorIds;

  /// Which MR currently covers this pharmacy for RCPA visits. Nullable, same
  /// reasoning as [Doctor.assignedMrUid].
  final String? assignedMrUid;
  final String? assignedMrName;

  final bool active;
  final String? createdByUid;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Pharmacy({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    this.linkedDoctorIds = const [],
    this.assignedMrUid,
    this.assignedMrName,
    this.active = true,
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory Pharmacy.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('Pharmacy.fromJson: parsing pharmacy id=$id');
    return Pharmacy(
      id: id,
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      linkedDoctorIds: List<String>.from(json['linkedDoctorIds'] as List? ?? const []),
      assignedMrUid: json['assignedMrUid'] as String?,
      assignedMrName: json['assignedMrName'] as String?,
      active: json['active'] as bool? ?? true,
      createdByUid: json['createdByUid'] as String?,
      createdByName: json['createdByName'] as String?,
      createdAt: _dateFromAny(json['createdAt']),
      updatedAt: _dateFromAny(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'linkedDoctorIds': linkedDoctorIds,
      'assignedMrUid': assignedMrUid,
      'assignedMrName': assignedMrName,
      'active': active,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
    };
  }

  Pharmacy copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? phone,
    List<String>? linkedDoctorIds,
    String? assignedMrUid,
    String? assignedMrName,
    bool? active,
  }) {
    return Pharmacy(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      linkedDoctorIds: linkedDoctorIds ?? this.linkedDoctorIds,
      assignedMrUid: assignedMrUid ?? this.assignedMrUid,
      assignedMrName: assignedMrName ?? this.assignedMrName,
      active: active ?? this.active,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        latitude,
        longitude,
        phone,
        linkedDoctorIds,
        assignedMrUid,
        assignedMrName,
        active,
        createdByUid,
        createdByName,
        createdAt,
        updatedAt,
      ];
}
