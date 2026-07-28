import 'package:equatable/equatable.dart';

/// One day's outcome for one doctor — requirement 7: "MR should update daily
/// which doctors he visited and their feedback or today's visit update".
/// Recorded locally first (offline-first, like [UsageSession]) and uploaded
/// in a batch when the MR syncs, typically in the evening (requirement 11).
class DoctorVisitLog extends Equatable {
  final String id;
  final String mrUid;
  final String doctorId;
  final String doctorName;

  /// Plain `"YYYY-MM-DD"`, same rationale as elsewhere in this app — this is
  /// "which calendar day was this visit", not a point in time.
  final String visitDate;
  final bool visited;
  final String feedback;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  /// Product/sample name -> quantity given during this visit — physician
  /// samples and promotional material handed out, tracked alongside the
  /// visit itself rather than as a separate feature, since samples are
  /// given during a visit in practice. Empty for a visit where nothing was
  /// given.
  final Map<String, int> samplesGiven;

  const DoctorVisitLog({
    required this.id,
    required this.mrUid,
    required this.doctorId,
    required this.doctorName,
    required this.visitDate,
    this.visited = true,
    this.feedback = '',
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.samplesGiven = const {},
  });

  @override
  List<Object?> get props =>
      [id, mrUid, doctorId, doctorName, visitDate, visited, feedback, latitude, longitude, createdAt, samplesGiven];
}
