import 'package:intl/intl.dart';

String formatTime(DateTime t) => DateFormat('h:mm a').format(t);
String formatTimeShort(DateTime t) => DateFormat('h:mm').format(t);
String formatAmPm(DateTime t) => DateFormat('a').format(t);

String formatDaysList(List<int> days) {
  if (days.isEmpty) return 'Once';
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'Weekdays';
  if (days.length == 2 && days.contains(6) && days.contains(7)) return 'Weekends';
  const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days.map((d) => names[d]).join(', ');
}

String timeUntilAlarm(DateTime fire) {
  final diff = fire.difference(DateTime.now());
  if (diff.isNegative) return 'Now';
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
