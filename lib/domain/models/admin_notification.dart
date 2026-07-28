import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// An in-app notification for the admin, currently only ever created by the
/// `onEmployeeDobChanged` Cloud Function trigger (see
/// functions/src/index.ts) when an MR's date of birth is set or changed.
class AdminNotification extends Equatable {
  final String id;
  final String employeeUid;
  final String employeeName;
  final String message;
  final DateTime? createdAt;
  final bool read;

  const AdminNotification({
    required this.id,
    required this.employeeUid,
    required this.employeeName,
    required this.message,
    this.createdAt,
    this.read = false,
  });

  factory AdminNotification.fromJson(String id, Map<String, dynamic> json) {
    return AdminNotification(
      id: id,
      employeeUid: json['employeeUid'] as String? ?? '',
      employeeName: json['employeeName'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      read: json['read'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, employeeUid, employeeName, message, createdAt, read];
}
