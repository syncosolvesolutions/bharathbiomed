import 'package:equatable/equatable.dart';

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
  });

  String get displayName => '$firstName $lastName';

  /// What this MR actually types to log in — their real email if they have
  /// one on file, otherwise their username.
  String get loginIdentifier => (email != null && email!.isNotEmpty) ? email! : username;

  factory Employee.fromJson(String uid, Map<String, dynamic> json) {
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
    );
  }

  @override
  List<Object?> get props =>
      [uid, username, firstName, lastName, designation, areaName, mobileNumber, photoUrl, email, disabled];
}
