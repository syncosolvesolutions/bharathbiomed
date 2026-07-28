import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A distributor/stockist that orders stock from the company and supplies it
/// on to pharmacies. Created directly only by an Office Admin (an employee
/// whose designation category is `office_administration`, or the hardcoded
/// admin) — an MR proposes a new one via [EntityChangeRequest] instead. See
/// firestore.rules for the enforcement and `manage_agencies` in
/// [Permission] for who else may update (not create/deactivate) one.
class Agency extends Equatable {
  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? gstNumber;

  /// Whether this agency can still receive/place orders. A deactivated
  /// agency is kept (not deleted) so its order history stays intact.
  final bool active;

  final String? createdByUid;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Agency({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.address,
    this.latitude,
    this.longitude,
    this.gstNumber,
    this.active = true,
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory Agency.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('Agency.fromJson: parsing agency id=$id');
    return Agency(
      id: id,
      name: json['name'] as String? ?? '',
      contactPerson: json['contactPerson'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      gstNumber: json['gstNumber'] as String?,
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
      'contactPerson': contactPerson,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'gstNumber': gstNumber,
      'active': active,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
    };
  }

  Agency copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    String? gstNumber,
    bool? active,
  }) {
    return Agency(
      id: id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gstNumber: gstNumber ?? this.gstNumber,
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
        contactPerson,
        phone,
        address,
        latitude,
        longitude,
        gstNumber,
        active,
        createdByUid,
        createdByName,
        createdAt,
        updatedAt,
      ];
}
