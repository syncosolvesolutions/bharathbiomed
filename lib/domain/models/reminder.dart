import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// A reminder shown to whoever is [ownerUid] — requirement 15/16: reminders
/// for both admin and MR. The admin can create a reminder for themselves
/// (`ownerUid == createdByUid`) or assign one to an MR (`ownerUid` is that
/// MR's uid); an MR can only ever create reminders for themselves. A push
/// notification is sent to [ownerUid]'s device when [dueAt] arrives (see the
/// `sendDueReminders` scheduled Cloud Function).
class Reminder extends Equatable {
  final String id;
  final String ownerUid;
  final String ownerName;
  final String createdByUid;
  final String createdByName;
  final String title;
  final String note;
  final DateTime dueAt;
  final bool completed;
  final DateTime? createdAt;

  const Reminder({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.createdByUid,
    required this.createdByName,
    required this.title,
    this.note = '',
    required this.dueAt,
    this.completed = false,
    this.createdAt,
  });

  bool get isOverdue => !completed && dueAt.isBefore(DateTime.now());

  factory Reminder.fromJson(String id, Map<String, dynamic> json) {
    debugPrint('Reminder.fromJson: parsing reminder id=$id');
    return Reminder(
      id: id,
      ownerUid: json['ownerUid'] as String? ?? '',
      ownerName: json['ownerName'] as String? ?? '',
      createdByUid: json['createdByUid'] as String? ?? '',
      createdByName: json['createdByName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      dueAt: (json['dueAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completed: json['completed'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'ownerUid': ownerUid,
      'ownerName': ownerName,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'title': title,
      'note': note,
      'dueAt': Timestamp.fromDate(dueAt),
      'completed': false,
      'notified': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props =>
      [id, ownerUid, ownerName, createdByUid, createdByName, title, note, dueAt, completed, createdAt];
}
