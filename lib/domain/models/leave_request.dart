import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A fixed leave-type set, same rationale as [ExpenseCategory] — standard
/// across Indian pharma field-force HR policy, not tenant-configurable.
enum LeaveType { sick, casual, earned, other }

LeaveType leaveTypeFromString(String? value) {
  switch (value) {
    case 'sick':
      return LeaveType.sick;
    case 'earned':
      return LeaveType.earned;
    case 'other':
      return LeaveType.other;
    default:
      return LeaveType.casual;
  }
}

String leaveTypeToJson(LeaveType type) => switch (type) {
      LeaveType.sick => 'sick',
      LeaveType.casual => 'casual',
      LeaveType.earned => 'earned',
      LeaveType.other => 'other',
    };

extension LeaveTypeLabel on LeaveType {
  String get label => switch (this) {
        LeaveType.sick => 'Sick Leave',
        LeaveType.casual => 'Casual Leave',
        LeaveType.earned => 'Earned/Privilege Leave',
        LeaveType.other => 'Other',
      };
}

/// `pending` (submitted here) -> `approved`/`rejected` by whoever holds
/// `approve_leave` for this MR's reporting chain — same simple two-step
/// lifecycle as [ExpenseClaimStatus] (nothing to fulfill once decided).
enum LeaveRequestStatus { pending, approved, rejected }

LeaveRequestStatus leaveRequestStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return LeaveRequestStatus.approved;
    case 'rejected':
      return LeaveRequestStatus.rejected;
    default:
      return LeaveRequestStatus.pending;
  }
}

String leaveRequestStatusToJson(LeaveRequestStatus status) => switch (status) {
      LeaveRequestStatus.pending => 'pending',
      LeaveRequestStatus.approved => 'approved',
      LeaveRequestStatus.rejected => 'rejected',
    };

/// An MR's leave request, offline-first like [ExpenseClaim] (queued
/// locally, uploaded on the next sync). [startDate]/[endDate] are plain
/// `"YYYY-MM-DD"`, same rationale as elsewhere in this app — these are
/// calendar days, not points in time; a single-day leave has
/// `startDate == endDate`.
class LeaveRequest extends Equatable {
  final String id;
  final String mrUid;
  final String mrName;
  final LeaveType leaveType;
  final String startDate;
  final String endDate;
  final String reason;
  final LeaveRequestStatus status;
  final String? approvedByUid;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final DateTime? createdAt;

  const LeaveRequest({
    required this.id,
    required this.mrUid,
    required this.mrName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason = '',
    this.status = LeaveRequestStatus.pending,
    this.approvedByUid,
    this.approvedAt,
    this.rejectedReason,
    this.createdAt,
  });

  factory LeaveRequest.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('LeaveRequest.fromJson: parsing request id=$id');
    return LeaveRequest(
      id: id,
      mrUid: json['mrUid'] as String? ?? '',
      mrName: json['mrName'] as String? ?? '',
      leaveType: leaveTypeFromString(json['leaveType'] as String?),
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: leaveRequestStatusFromString(json['status'] as String?),
      approvedByUid: json['approvedByUid'] as String?,
      approvedAt: _dateFromAny(json['approvedAt']),
      rejectedReason: json['rejectedReason'] as String?,
      createdAt: _dateFromAny(json['createdAt']),
    );
  }

  /// For the initial (offline) create — server-assigned fields are
  /// deliberately omitted, mirrors [ExpenseClaim.toCreateJson].
  Map<String, dynamic> toCreateJson() {
    return {
      'mrUid': mrUid,
      'mrName': mrName,
      'leaveType': leaveTypeToJson(leaveType),
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'status': 'pending',
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
        mrName,
        leaveType,
        startDate,
        endDate,
        reason,
        status,
        approvedByUid,
        approvedAt,
        rejectedReason,
        createdAt,
      ];
}
