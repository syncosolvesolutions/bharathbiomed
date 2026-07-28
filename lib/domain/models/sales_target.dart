import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A monthly order-value target an RM-or-above sets for one of their
/// reporting-chain downline (see `manage_targets` in [Permission] and
/// `isInDownlineOf` in firestore.rules). [period] is a plain `"YYYY-MM"`
/// string, same rationale as [Employee.dateOfBirth] — a month has no
/// meaningful time-of-day/timezone component. Achievement is deliberately
/// not a field here — it's a live rollup of that employee's real [Order]
/// totals for the period (see `MyTargetController`/`TeamTargetsController`),
/// not a separate number someone could edit by hand.
class SalesTarget extends Equatable {
  final String id;
  final String employeeUid;
  final String period;
  final double targetValue;
  final String createdByUid;
  final DateTime? createdAt;

  const SalesTarget({
    required this.id,
    required this.employeeUid,
    required this.period,
    required this.targetValue,
    required this.createdByUid,
    this.createdAt,
  });

  factory SalesTarget.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('SalesTarget.fromJson: parsing target id=$id');
    return SalesTarget(
      id: id,
      employeeUid: json['employeeUid'] as String? ?? '',
      period: json['period'] as String? ?? '',
      targetValue: (json['targetValue'] as num?)?.toDouble() ?? 0,
      createdByUid: json['createdByUid'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeUid': employeeUid,
        'period': period,
        'targetValue': targetValue,
        'createdByUid': createdByUid,
      };

  @override
  List<Object?> get props => [id, employeeUid, period, targetValue, createdByUid, createdAt];
}

/// `"YYYY-MM"` for [now] — the current period, used as the default when
/// setting or viewing a target.
String currentTargetPeriod([DateTime? now]) {
  final date = now ?? DateTime.now();
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
