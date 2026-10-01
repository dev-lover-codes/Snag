const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `14:05`
String formatTime(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// `Oct 3` (adds the year when it differs from [now]).
String formatShortDate(DateTime d, {DateTime? now}) {
  final l = d.toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  final base = '${_months[l.month - 1]} ${l.day}';
  return l.year == n.year ? base : '$base, ${l.year}';
}

/// `Oct 3, 14:05`
String formatDateTime(DateTime d, {DateTime? now}) =>
    '${formatShortDate(d, now: now)}, ${formatTime(d)}';

DateTime _dayOf(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

bool isSameDay(DateTime a, DateTime b) => _dayOf(a) == _dayOf(b);

/// Chat date separator: Today, Yesterday, then `Oct 3`.
String daySeparatorLabel(DateTime d, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final day = _dayOf(d);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return formatShortDate(d, now: now);
}

/// Chat list time: `14:05` today, `Yesterday`, else `Oct 3`.
String chatListTime(DateTime d, {DateTime? now}) {
  final label = daySeparatorLabel(d, now: now);
  return label == 'Today' ? formatTime(d) : label;
}

/// `1.2 MB`, `340 KB`
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Calendar group label: Today, Tomorrow, Yesterday, then `Mon, Oct 3`.
String eventDayLabel(DateTime d, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final diff = _dayOf(d).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.toLocal().weekday - 1]}, ${formatShortDate(d, now: now)}';
}

/// Start of the local day containing [d].
DateTime startOfDay(DateTime d) => _dayOf(d);
