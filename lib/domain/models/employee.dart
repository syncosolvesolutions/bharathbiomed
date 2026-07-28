import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A Medical Representative account created by the admin. Login itself is
/// handled by Firebase Auth (see [EmployeeRepository.create]); this is just
/// the profile data admin fills in about them.
///
/// [email] is required for every account created or edited going forward —
/// it's this account's actual Firebase Auth sign-in email, so the MR logs in
/// with it directly and can use native "forgot password". Accounts created
/// before email became mandatory may still have a null [email]; those fall
/// back to signing in via [username] resolved to a synthetic address (see
/// core/auth/employee_login.dart) until an admin edits the profile and adds
/// one.
class Employee extends Equatable {
  final String uid;
  final String username;
  final String firstName;
  final String lastName;
  final String designation;
  final String areaName;
  final String? mobileNumber;
  final String? photoUrl;
  final String? email;

  /// Whether the admin has suspended this account (Firebase Auth `disabled`
  /// flag, mirrored here). A suspended MR can't sign in — Firebase rejects
  /// it with `user-disabled`, shown to them as "This account has been
  /// disabled. Contact your administrator." — but their profile and usage
  /// history are kept, unlike deleting the employee outright.
  final bool disabled;

  /// Plain `"YYYY-MM-DD"` string rather than a `Timestamp`/`DateTime` — this
  /// is a date-only value (no meaningful time-of-day or timezone), so
  /// storing it as a string sidesteps timezone-shift bugs when comparing
  /// month/day for the birthday check below. Settable by the admin
  /// (create/edit) or by the MR themselves via the Profile screen.
  final String? dateOfBirth;

  /// Whether this MR has completed the mandatory first-login profile setup
  /// (requirement: photo + name before using the rest of the app). Defaults
  /// to `true` when absent so accounts that existed before this field was
  /// introduced are never retroactively blocked — only accounts created
  /// after this shipped start out `false` (see functions/src/index.ts
  /// `createEmployee`).
  final bool profileCompleted;

  /// FK -> Designations/{id}. Additive alongside [designation] (the free
  /// display string) — null for every account until an admin assigns one
  /// through the updated employee form, so existing accounts keep working
  /// unchanged.
  final String? designationId;

  /// FK -> Users/{uid}, this employee's direct manager. Null until assigned.
  final String? managerId;

  /// Server-computed (see `functions/src/hierarchy.ts`), direct-manager-first
  /// ordered list of every manager above this employee. Empty until
  /// [managerId] is set and the recompute trigger has run.
  final List<String> reportingChainUids;

  /// Denormalized copy of `Designations/{designationId}.permissions`, kept in
  /// sync by the same trigger that computes [reportingChainUids].
  final List<String> permissions;

  /// Denormalized copy of the assigned designation's hierarchyLevel/category.
  final int? hierarchyLevel;
  final String? category;

  const Employee({
    required this.uid,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.designation,
    required this.areaName,
    this.mobileNumber,
    this.photoUrl,
    this.email,
    this.disabled = false,
    this.dateOfBirth,
    this.profileCompleted = true,
    this.designationId,
    this.managerId,
    this.reportingChainUids = const [],
    this.permissions = const [],
    this.hierarchyLevel,
    this.category,
  });

  String get displayName => '$firstName $lastName';

  /// What this MR actually types to log in — their real email if they have
  /// one on file, otherwise their username.
  String get loginIdentifier => (email != null && email!.isNotEmpty) ? email! : username;

  /// Whether today is this employee's birthday, comparing month/day only
  /// (the year in [dateOfBirth] is irrelevant here).
  bool get isBirthdayToday {
    debugPrint('Employee.isBirthdayToday: checking birthday for uid=$uid dateOfBirth=$dateOfBirth');
    final dob = dateOfBirth;
    if (dob == null || dob.isEmpty) return false;
    final parts = dob.split('-');
    if (parts.length != 3) return false;
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null) return false;
    final now = DateTime.now();
    return now.month == month && now.day == day;
  }

  factory Employee.fromJson(String uid, Map<String, dynamic> json) {
    debugPrint('Employee.fromJson: parsing employee document uid=$uid');
    return Employee(
      uid: uid,
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
      areaName: json['areaName'] as String? ?? '',
      mobileNumber: json['mobileNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      email: json['email'] as String?,
      disabled: json['disabled'] as bool? ?? false,
      dateOfBirth: json['dateOfBirth'] as String?,
      profileCompleted: json['profileCompleted'] as bool? ?? true,
      designationId: json['designationId'] as String?,
      managerId: json['managerId'] as String?,
      reportingChainUids: List<String>.from(json['reportingChainUids'] as List? ?? const []),
      permissions: List<String>.from(json['permissions'] as List? ?? const []),
      hierarchyLevel: (json['hierarchyLevel'] as num?)?.toInt(),
      category: json['category'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        username,
        firstName,
        lastName,
        designation,
        areaName,
        mobileNumber,
        profileCompleted,
        photoUrl,
        email,
        disabled,
        dateOfBirth,
        designationId,
        managerId,
        reportingChainUids,
        permissions,
        hierarchyLevel,
        category,
      ];
}
