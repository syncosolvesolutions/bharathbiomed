import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A doctor an MR visits, created either directly by the admin (auto-live)
/// or by an MR out in the field (goes through [DoctorChangeRequest] approval
/// first — see that model). [name] and [hospitalName] are always required;
/// at least one of [latitude]/[longitude], [locationAddress] or
/// [googleMapsLink] must be set, but which one is up to whoever's filling
/// the form — an MR standing outside a hospital for the first time may only
/// have a GPS fix, while the admin back-filling a doctor from a business
/// card may only have an address.
class Doctor extends Equatable {
  final String id;
  final String name;
  final String specialisation;
  final String hospitalName;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? googleMapsLink;

  /// At most 2 entries — enforced by the form, not this model. Each entry is
  /// independently replaceable (re-upload overwrites that slot's URL).
  final List<String> doctorPhotoUrls;
  final List<String> hospitalPhotoUrls;

  /// Plain `"YYYY-MM-DD"` strings, same rationale as [Employee.dateOfBirth].
  final String? dateOfBirth;
  final String? marriageAnniversary;

  /// Which MR currently visits this doctor. Nullable: a doctor can exist
  /// unassigned right after creation until the admin assigns one (see
  /// requirement 2/8 — admin creates/reassigns MR-to-doctor assignments).
  final String? assignedMrUid;
  final String? assignedMrName;

  final String? createdByUid;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Doctor({
    required this.id,
    required this.name,
    this.specialisation = '',
    required this.hospitalName,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.googleMapsLink,
    this.doctorPhotoUrls = const [],
    this.hospitalPhotoUrls = const [],
    this.dateOfBirth,
    this.marriageAnniversary,
    this.assignedMrUid,
    this.assignedMrName,
    this.createdByUid,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasLocation =>
      (latitude != null && longitude != null) ||
      (locationAddress != null && locationAddress!.isNotEmpty) ||
      (googleMapsLink != null && googleMapsLink!.isNotEmpty);

  /// Comparing month/day only, same as [Employee.isBirthdayToday].
  bool _isTodayFor(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return false;
    final parts = isoDate.split('-');
    if (parts.length != 3) return false;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null) return false;
    final now = DateTime.now();
    return now.month == month && now.day == day;
  }

  bool get isBirthdayToday => _isTodayFor(dateOfBirth);
  bool get isAnniversaryToday => _isTodayFor(marriageAnniversary);

  factory Doctor.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('Doctor.fromJson: parsing doctor id=$id');
    return Doctor(
      id: id,
      name: json['name'] as String? ?? '',
      specialisation: json['specialisation'] as String? ?? '',
      hospitalName: json['hospitalName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAddress: json['locationAddress'] as String?,
      googleMapsLink: json['googleMapsLink'] as String?,
      doctorPhotoUrls: List<String>.from(json['doctorPhotoUrls'] as List? ?? const []),
      hospitalPhotoUrls: List<String>.from(json['hospitalPhotoUrls'] as List? ?? const []),
      dateOfBirth: json['dateOfBirth'] as String?,
      marriageAnniversary: json['marriageAnniversary'] as String?,
      assignedMrUid: json['assignedMrUid'] as String?,
      assignedMrName: json['assignedMrName'] as String?,
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
      'specialisation': specialisation,
      'hospitalName': hospitalName,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
      'googleMapsLink': googleMapsLink,
      'doctorPhotoUrls': doctorPhotoUrls,
      'hospitalPhotoUrls': hospitalPhotoUrls,
      'dateOfBirth': dateOfBirth,
      'marriageAnniversary': marriageAnniversary,
      'assignedMrUid': assignedMrUid,
      'assignedMrName': assignedMrName,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
    };
  }

  Doctor copyWith({
    String? name,
    String? specialisation,
    String? hospitalName,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? googleMapsLink,
    List<String>? doctorPhotoUrls,
    List<String>? hospitalPhotoUrls,
    String? dateOfBirth,
    String? marriageAnniversary,
    String? assignedMrUid,
    String? assignedMrName,
  }) {
    return Doctor(
      id: id,
      name: name ?? this.name,
      specialisation: specialisation ?? this.specialisation,
      hospitalName: hospitalName ?? this.hospitalName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAddress: locationAddress ?? this.locationAddress,
      googleMapsLink: googleMapsLink ?? this.googleMapsLink,
      doctorPhotoUrls: doctorPhotoUrls ?? this.doctorPhotoUrls,
      hospitalPhotoUrls: hospitalPhotoUrls ?? this.hospitalPhotoUrls,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      marriageAnniversary: marriageAnniversary ?? this.marriageAnniversary,
      assignedMrUid: assignedMrUid ?? this.assignedMrUid,
      assignedMrName: assignedMrName ?? this.assignedMrName,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    // Firestore Timestamp has a toDate() method; avoid importing
    // cloud_firestore here so this model stays storage-agnostic (the local
    // sqlite cache also constructs Doctor instances from plain ints).
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
        specialisation,
        hospitalName,
        latitude,
        longitude,
        locationAddress,
        googleMapsLink,
        doctorPhotoUrls,
        hospitalPhotoUrls,
        dateOfBirth,
        marriageAnniversary,
        assignedMrUid,
        assignedMrName,
        createdByUid,
        createdByName,
        createdAt,
        updatedAt,
      ];
}
