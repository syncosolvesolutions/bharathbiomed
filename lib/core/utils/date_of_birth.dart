/// Shared helpers for the plain `"YYYY-MM-DD"` date-of-birth strings stored
/// on [Employee.dateOfBirth]/[AdminProfile.dateOfBirth] — see either model
/// for why a date-only string is used instead of a `Timestamp`/`DateTime`.
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String isoFromDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime? dateFromIso(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String formatIsoForDisplay(String? iso) {
  final date = dateFromIso(iso);
  if (date == null) return 'Not set';
  return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
}
