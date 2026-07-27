String formatDuration(Duration duration) {
  // A negative duration means closedAt ended up before openedAt (clock skew
  // or corrupt data) — surface that instead of silently showing "<1m" as if
  // it were a normal short session.
  if (duration.isNegative) return 'invalid';
  if (duration.inMinutes < 1) return '<1m';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
