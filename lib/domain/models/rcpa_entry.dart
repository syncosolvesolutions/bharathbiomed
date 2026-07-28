import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// How many scripts for one of the company's own products this MR counted
/// during the audit.
class RcpaProductCount extends Equatable {
  final String productId;
  final String productName;
  final int count;

  const RcpaProductCount({required this.productId, required this.productName, required this.count});

  factory RcpaProductCount.fromJson(Map<String, dynamic> json) => RcpaProductCount(
        productId: json['productId'] as String? ?? '',
        productName: json['productName'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'productId': productId, 'productName': productName, 'count': count};

  @override
  List<Object?> get props => [productId, productName, count];
}

/// How many scripts for a competitor brand this MR counted — freeform, since
/// there's no catalog of competitor products to pick from.
class RcpaCompetitorCount extends Equatable {
  final String brandName;
  final int count;

  const RcpaCompetitorCount({required this.brandName, required this.count});

  factory RcpaCompetitorCount.fromJson(Map<String, dynamic> json) => RcpaCompetitorCount(
        brandName: json['brandName'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'brandName': brandName, 'count': count};

  @override
  List<Object?> get props => [brandName, count];
}

/// A Retail Chemist Prescription Audit: an MR counts, at one [Pharmacy],
/// how many prescriptions filled there are for the company's own products
/// versus competitor brands — the ground-truth signal that a doctor visit
/// converted to an actual prescription, not just activity. Append-only,
/// offline-first, same shape as [DoctorVisitLog].
class RcpaEntry extends Equatable {
  final String id;
  final String mrUid;
  final String pharmacyId;
  final String pharmacyName;
  final String auditDate;
  final List<RcpaProductCount> ownBrandCounts;
  final List<RcpaCompetitorCount> competitorCounts;
  final String notes;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const RcpaEntry({
    required this.id,
    required this.mrUid,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.auditDate,
    this.ownBrandCounts = const [],
    this.competitorCounts = const [],
    this.notes = '',
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  int get totalOwnBrandCount => ownBrandCounts.fold(0, (sum, entry) => sum + entry.count);
  int get totalCompetitorCount => competitorCounts.fold(0, (sum, entry) => sum + entry.count);

  factory RcpaEntry.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('RcpaEntry.fromJson: parsing entry id=$id');
    return RcpaEntry(
      id: id,
      mrUid: json['mrUid'] as String? ?? '',
      pharmacyId: json['pharmacyId'] as String? ?? '',
      pharmacyName: json['pharmacyName'] as String? ?? '',
      auditDate: json['auditDate'] as String? ?? '',
      ownBrandCounts: (json['ownBrandCounts'] as List? ?? const [])
          .map((entry) => RcpaProductCount.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList(),
      competitorCounts: (json['competitorCounts'] as List? ?? const [])
          .map((entry) => RcpaCompetitorCount.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList(),
      notes: json['notes'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: _dateFromAny(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mrUid': mrUid,
      'pharmacyId': pharmacyId,
      'pharmacyName': pharmacyName,
      'auditDate': auditDate,
      'ownBrandCounts': ownBrandCounts.map((entry) => entry.toJson()).toList(),
      'competitorCounts': competitorCounts.map((entry) => entry.toJson()).toList(),
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
    };
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
        mrUid,
        pharmacyId,
        pharmacyName,
        auditDate,
        ownBrandCounts,
        competitorCounts,
        notes,
        latitude,
        longitude,
        createdAt,
      ];
}
