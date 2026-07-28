import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Monday-first, matching [DateTime.weekday] (1 = Monday .. 7 = Sunday) so
/// `weekdayKeys[DateTime.now().weekday - 1]` gives "today"'s key directly.
const weekdayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const weekdayLabels = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String weekdayKeyForToday() => weekdayKeys[DateTime.now().weekday - 1];

/// An MR's recurring weekly visiting schedule — one doc per MR
/// (`DoctorVisitPlans/{mrUid}`), requirement 13/14: "Doctors visiting plan
/// should be like weekdays like monday whom he visits and tuesday whom [...]
/// like that". Each weekday maps to the list of doctor ids planned for that
/// day; a doctor can appear on more than one day (e.g. a high-priority
/// doctor visited twice a week).
class DoctorVisitPlan extends Equatable {
  final String mrUid;
  final Map<String, List<String>> doctorIdsByWeekday;
  final DateTime? updatedAt;

  const DoctorVisitPlan({required this.mrUid, this.doctorIdsByWeekday = const {}, this.updatedAt});

  List<String> forWeekday(String weekdayKey) => doctorIdsByWeekday[weekdayKey] ?? const [];

  List<String> get forToday => forWeekday(weekdayKeyForToday());

  bool get isEmpty => doctorIdsByWeekday.values.every((list) => list.isEmpty);

  factory DoctorVisitPlan.fromJson(String mrUid, Map<String, dynamic> json) {
    debugPrint('DoctorVisitPlan.fromJson: parsing plan mrUid=$mrUid');
    final map = <String, List<String>>{};
    for (final key in weekdayKeys) {
      map[key] = List<String>.from(json[key] as List? ?? const []);
    }
    return DoctorVisitPlan(mrUid: mrUid, doctorIdsByWeekday: map);
  }

  Map<String, dynamic> toJson() => {for (final key in weekdayKeys) key: doctorIdsByWeekday[key] ?? const []};

  DoctorVisitPlan copyWithWeekday(String weekdayKey, List<String> doctorIds) {
    final updated = Map<String, List<String>>.from(doctorIdsByWeekday);
    updated[weekdayKey] = doctorIds;
    return DoctorVisitPlan(mrUid: mrUid, doctorIdsByWeekday: updated, updatedAt: updatedAt);
  }

  @override
  List<Object?> get props => [mrUid, doctorIdsByWeekday, updatedAt];
}
