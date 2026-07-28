import 'package:equatable/equatable.dart';

/// The admin's own editable profile. Unlike [Employee], the admin has no
/// `Users` doc — they're just an allowlisted email (see
/// `core/auth/admin_access.dart`) — so this is its own small Firestore doc
/// (`AdminProfile/{uid}`) the admin can read/write directly, since it's
/// low-sensitivity self-owned data and they're already fully trusted.
class AdminProfile extends Equatable {
  final String uid;
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final String? mobileNumber;

  /// Plain `"YYYY-MM-DD"` string — see [Employee.dateOfBirth] for why.
  final String? dateOfBirth;

  const AdminProfile({
    required this.uid,
    this.firstName = '',
    this.lastName = '',
    this.photoUrl,
    this.mobileNumber,
    this.dateOfBirth,
  });

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Admin' : name;
  }

  factory AdminProfile.fromJson(String uid, Map<String, dynamic> json) {
    return AdminProfile(
      uid: uid,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      mobileNumber: json['mobileNumber'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (mobileNumber != null) 'mobileNumber': mobileNumber,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
    };
  }

  @override
  List<Object?> get props => [uid, firstName, lastName, photoUrl, mobileNumber, dateOfBirth];
}
