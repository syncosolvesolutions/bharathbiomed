import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// What an [ExpenseClaim] is for — a plain TA/DA (Travel & Daily
/// Allowance) claim category set. Kept as a fixed enum (not a tenant-
/// configurable list like `Designation`) since these categories are
/// standard across pharma field-force claims and drive nothing else in the
/// app; if a tenant ever needs custom categories, `other` plus
/// [ExpenseClaim.description] covers it.
enum ExpenseCategory { travel, dailyAllowance, lodging, other }

ExpenseCategory expenseCategoryFromString(String? value) {
  switch (value) {
    case 'travel':
      return ExpenseCategory.travel;
    case 'lodging':
      return ExpenseCategory.lodging;
    case 'other':
      return ExpenseCategory.other;
    default:
      return ExpenseCategory.dailyAllowance;
  }
}

String expenseCategoryToJson(ExpenseCategory category) => switch (category) {
      ExpenseCategory.travel => 'travel',
      ExpenseCategory.dailyAllowance => 'dailyAllowance',
      ExpenseCategory.lodging => 'lodging',
      ExpenseCategory.other => 'other',
    };

extension ExpenseCategoryLabel on ExpenseCategory {
  String get label => switch (this) {
        ExpenseCategory.travel => 'Travel',
        ExpenseCategory.dailyAllowance => 'Daily Allowance',
        ExpenseCategory.lodging => 'Lodging',
        ExpenseCategory.other => 'Other',
      };
}

/// `pending` (submitted here) -> `approved`/`rejected` by whoever holds
/// `approve_expenses` for this MR's reporting chain — a deliberately
/// simpler lifecycle than [Order] (no dispatch/delivery equivalent; a claim
/// is either approved or it isn't, there's nothing further to fulfill).
enum ExpenseClaimStatus { pending, approved, rejected }

ExpenseClaimStatus expenseClaimStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return ExpenseClaimStatus.approved;
    case 'rejected':
      return ExpenseClaimStatus.rejected;
    default:
      return ExpenseClaimStatus.pending;
  }
}

String expenseClaimStatusToJson(ExpenseClaimStatus status) => switch (status) {
      ExpenseClaimStatus.pending => 'pending',
      ExpenseClaimStatus.approved => 'approved',
      ExpenseClaimStatus.rejected => 'rejected',
    };

/// An MR's travel/daily-allowance/lodging expense claim, offline-first like
/// [DoctorVisitLog] and [Order] (queued locally, uploaded on the next
/// sync). [receiptPhotoUrl] is the one field that is NOT offline-first:
/// attaching a receipt photo requires connectivity at submission time (see
/// `ExpenseClaimFormScreen`'s use of `PhotoPickerField`, which uploads
/// immediately to Firebase Storage) — unlike the rest of this app's photo
/// fields, which are all admin-only and admin is assumed always online.
/// Submitting without a photo, or with one added later by re-editing before
/// approval, both work; there's no local-blob-then-sync pipeline for images
/// in this app today.
class ExpenseClaim extends Equatable {
  final String id;
  final String mrUid;
  final String mrName;
  final ExpenseCategory category;

  /// Plain `"YYYY-MM-DD"`, same rationale as [DoctorVisitLog.visitDate] —
  /// this is "which calendar day was this expense incurred," not a point
  /// in time.
  final String claimDate;
  final double amount;
  final String description;
  final String? receiptPhotoUrl;
  final ExpenseClaimStatus status;
  final String? approvedByUid;
  final DateTime? approvedAt;
  final String? rejectedReason;
  final DateTime? createdAt;

  const ExpenseClaim({
    required this.id,
    required this.mrUid,
    required this.mrName,
    required this.category,
    required this.claimDate,
    required this.amount,
    this.description = '',
    this.receiptPhotoUrl,
    this.status = ExpenseClaimStatus.pending,
    this.approvedByUid,
    this.approvedAt,
    this.rejectedReason,
    this.createdAt,
  });

  factory ExpenseClaim.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('ExpenseClaim.fromJson: parsing claim id=$id');
    return ExpenseClaim(
      id: id,
      mrUid: json['mrUid'] as String? ?? '',
      mrName: json['mrName'] as String? ?? '',
      category: expenseCategoryFromString(json['category'] as String?),
      claimDate: json['claimDate'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      receiptPhotoUrl: json['receiptPhotoUrl'] as String?,
      status: expenseClaimStatusFromString(json['status'] as String?),
      approvedByUid: json['approvedByUid'] as String?,
      approvedAt: _dateFromAny(json['approvedAt']),
      rejectedReason: json['rejectedReason'] as String?,
      createdAt: _dateFromAny(json['createdAt']),
    );
  }

  /// For the initial (offline) create — server-assigned fields
  /// (`approvedByUid`, `approvedAt`, etc.) are deliberately omitted since
  /// only Firestore/the review actions ever set them. Mirrors
  /// [Order.toCreateJson].
  Map<String, dynamic> toCreateJson() {
    return {
      'mrUid': mrUid,
      'mrName': mrName,
      'category': expenseCategoryToJson(category),
      'claimDate': claimDate,
      'amount': amount,
      'description': description,
      'receiptPhotoUrl': receiptPhotoUrl,
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
        category,
        claimDate,
        amount,
        description,
        receiptPhotoUrl,
        status,
        approvedByUid,
        approvedAt,
        rejectedReason,
        createdAt,
      ];
}
