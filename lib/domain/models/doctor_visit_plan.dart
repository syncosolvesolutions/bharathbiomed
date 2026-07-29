import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Monday-first, matching [DateTime.weekday] (1 = Monday .. 7 = Sunday) so
/// `weekdayKeys[DateTime.now().weekday - 1]` gives "today"'s key directly.
const weekdayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const weekdayLabels = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String weekdayKeyForToday() => weekdayKeys[DateTime.now().weekday - 1];

/// `draft` (never submitted, or edited after a decision — see
/// [DoctorVisitPlan.copyWithWeekday]'s doc comment) -> `pending` (the MR
/// submitted it) -> `approved`/`rejected` by a manager holding
/// `approve_requests` for this MR's reporting chain. Unlike [OrderStatus],
/// there's no further step after approved/rejected — this just records
/// whether a manager has signed off on the current plan.
enum VisitPlanStatus { draft, pending, approved, rejected }

VisitPlanStatus visitPlanStatusFromString(String? value) {
  switch (value) {
    case 'pending':
      return VisitPlanStatus.pending;
    case 'approved':
      return VisitPlanStatus.approved;
    case 'rejected':
      return VisitPlanStatus.rejected;
    default:
      return VisitPlanStatus.draft;
  }
}

String visitPlanStatusToJson(VisitPlanStatus status) => switch (status) {
      VisitPlanStatus.draft => 'draft',
      VisitPlanStatus.pending => 'pending',
      VisitPlanStatus.approved => 'approved',
      VisitPlanStatus.rejected => 'rejected',
    };

/// An MR's recurring weekly visiting schedule — one doc per MR
/// (`DoctorVisitPlans/{mrUid}`), requirement 13/14: "Doctors visiting plan
/// should be like weekdays like monday whom he visits and tuesday whom [...]
/// like that". Each weekday maps to the list of doctor ids planned for that
/// day; a doctor can appear on more than one day (e.g. a high-priority
/// doctor visited twice a week).
///
/// [status]/[approvedByUid]/[approvedAt]/[rejectedReason] add a beat/route
/// plan approval workflow on top of that: the MR submits the current
/// content for review ([VisitPlanStatus.pending]), and a manager approves
/// or rejects it. Editing content (`copyWithWeekday`) does NOT clear an
/// existing `approved`/`rejected` decision back to `draft` — approval is a
/// snapshot-in-time signal a manager gave for whatever the plan looked like
/// when they reviewed it, not a continuously-enforced constraint; the MR
/// must explicitly submit again (see `DoctorVisitPlanController
/// .submitForApproval`) if they want a fresh sign-off after editing.
/// `firestore.rules` blocks content edits entirely while [status] is
/// `pending`, so a review can't be raced against a content change.
class DoctorVisitPlan extends Equatable {
  final String mrUid;
  final Map<String, List<String>> doctorIdsByWeekday;
  final VisitPlanStatus status;
  final String? approvedByUid;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final DateTime? updatedAt;

  const DoctorVisitPlan({
    required this.mrUid,
    this.doctorIdsByWeekday = const {},
    this.status = VisitPlanStatus.draft,
    this.approvedByUid,
    this.approvedAt,
    this.rejectedReason,
    this.updatedAt,
  });

  List<String> forWeekday(String weekdayKey) => doctorIdsByWeekday[weekdayKey] ?? const [];

  List<String> get forToday => forWeekday(weekdayKeyForToday());

  bool get isEmpty => doctorIdsByWeekday.values.every((list) => list.isEmpty);

  factory DoctorVisitPlan.fromJson(String mrUid, Map<String, dynamic> json) {
    debugPrint('DoctorVisitPlan.fromJson: parsing plan mrUid=$mrUid');
    final map = <String, List<String>>{};
    for (final key in weekdayKeys) {
      map[key] = List<String>.from(json[key] as List? ?? const []);
    }
    return DoctorVisitPlan(
      mrUid: mrUid,
      doctorIdsByWeekday: map,
      status: visitPlanStatusFromString(json['status'] as String?),
      approvedByUid: json['approvedByUid'] as String?,
      approvedAt: _dateFromAny(json['approvedAt']),
      rejectedReason: json['rejectedReason'] as String?,
    );
  }

  /// Always includes the approval fields (even when unset) since this is
  /// written with a full-document `set()`, not a partial update — omitting
  /// them here would silently wipe an existing approval decision on the
  /// next content-only save. See `DoctorVisitPlanRemoteDataSource.save`.
  Map<String, dynamic> toJson() => {
        for (final key in weekdayKeys) key: doctorIdsByWeekday[key] ?? const [],
        'status': visitPlanStatusToJson(status),
        'approvedByUid': approvedByUid,
        'rejectedReason': rejectedReason,
      };

  DoctorVisitPlan copyWithWeekday(String weekdayKey, List<String> doctorIds) {
    final updated = Map<String, List<String>>.from(doctorIdsByWeekday);
    updated[weekdayKey] = doctorIds;
    return DoctorVisitPlan(
      mrUid: mrUid,
      doctorIdsByWeekday: updated,
      status: status,
      approvedByUid: approvedByUid,
      approvedAt: approvedAt,
      rejectedReason: rejectedReason,
      updatedAt: updatedAt,
    );
  }

  /// Used when the MR submits for approval — clears any previous decision
  /// so a stale approval/rejection reason doesn't linger next to a new
  /// pending request.
  DoctorVisitPlan copyAsPending() => DoctorVisitPlan(
        mrUid: mrUid,
        doctorIdsByWeekday: doctorIdsByWeekday,
        status: VisitPlanStatus.pending,
        updatedAt: updatedAt,
      );

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
      [mrUid, doctorIdsByWeekday, status, approvedByUid, approvedAt, rejectedReason, updatedAt];
}
