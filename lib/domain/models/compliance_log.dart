import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// What was given to a doctor, for UCPMP (Uniform Code for Pharmaceutical
/// Marketing Practices) compliance logging — India's pharma marketing code
/// restricts/prohibits gifts, sponsorships, and hospitality to prescribers,
/// so this exists to make what field reps actually gave visible and
/// auditable, not to encourage giving it. `sample` overlaps in spirit with
/// [DoctorVisitLog.samplesGiven] (product samples handed out during a
/// visit) but is tracked separately here because this log carries a
/// monetary [ComplianceLog.value] to check against
/// [TenantConfig.ucpmpAnnualLimitPerDoctor] — `samplesGiven` is just a
/// product-name-to-quantity map with no value attached.
enum ComplianceCategory { sample, gift, sponsorship, hospitality, other }

ComplianceCategory complianceCategoryFromString(String? value) {
  switch (value) {
    case 'sample':
      return ComplianceCategory.sample;
    case 'sponsorship':
      return ComplianceCategory.sponsorship;
    case 'hospitality':
      return ComplianceCategory.hospitality;
    case 'other':
      return ComplianceCategory.other;
    default:
      return ComplianceCategory.gift;
  }
}

String complianceCategoryToJson(ComplianceCategory category) => switch (category) {
      ComplianceCategory.sample => 'sample',
      ComplianceCategory.gift => 'gift',
      ComplianceCategory.sponsorship => 'sponsorship',
      ComplianceCategory.hospitality => 'hospitality',
      ComplianceCategory.other => 'other',
    };

extension ComplianceCategoryLabel on ComplianceCategory {
  String get label => switch (this) {
        ComplianceCategory.sample => 'Product Sample',
        ComplianceCategory.gift => 'Gift',
        ComplianceCategory.sponsorship => 'Sponsorship',
        ComplianceCategory.hospitality => 'Hospitality',
        ComplianceCategory.other => 'Other',
      };
}

/// A UCPMP compliance record: what an MR gave a doctor, and its value —
/// append-only, offline-first, same shape as [RcpaEntry]/[DoctorVisitLog]
/// (queued locally, uploaded on the next sync, never edited or deleted
/// afterward — an audit log that could be edited after the fact wouldn't
/// be much of an audit log).
class ComplianceLog extends Equatable {
  final String id;
  final String mrUid;
  final String mrName;
  final String doctorId;
  final String doctorName;
  final ComplianceCategory category;
  final String description;
  final double value;

  /// Plain `"YYYY-MM-DD"`, same rationale as elsewhere in this app.
  final String logDate;
  final DateTime createdAt;

  const ComplianceLog({
    required this.id,
    required this.mrUid,
    required this.mrName,
    required this.doctorId,
    required this.doctorName,
    required this.category,
    this.description = '',
    required this.value,
    required this.logDate,
    required this.createdAt,
  });

  factory ComplianceLog.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('ComplianceLog.fromJson: parsing log id=$id');
    return ComplianceLog(
      id: id,
      mrUid: json['mrUid'] as String? ?? '',
      mrName: json['mrName'] as String? ?? '',
      doctorId: json['doctorId'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? '',
      category: complianceCategoryFromString(json['category'] as String?),
      description: json['description'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      logDate: json['logDate'] as String? ?? '',
      createdAt: _dateFromAny(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'mrUid': mrUid,
        'mrName': mrName,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'category': complianceCategoryToJson(category),
        'description': description,
        'value': value,
        'logDate': logDate,
      };

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
  List<Object?> get props =>
      [id, mrUid, mrName, doctorId, doctorName, category, description, value, logDate, createdAt];
}
