class Alarm {
  final String id;
  final DateTime time;
  final String label;
  final bool enabled;
  final List<int> repeatDays; // 1=Mon..7=Sun, empty=one-shot
  final String ringtone;
  final bool vibrate;
  final String? focusLabel; // "Today's first focus"

  Alarm({
    required this.id,
    required this.time,
    this.label = '',
    this.enabled = true,
    this.repeatDays = const [],
    this.ringtone = 'default',
    this.vibrate = true,
    this.focusLabel,
  });

  Alarm copyWith({
    String? id,
    DateTime? time,
    String? label,
    bool? enabled,
    List<int>? repeatDays,
    String? ringtone,
    bool? vibrate,
    String? focusLabel,
  }) {
    return Alarm(
      id: id ?? this.id,
      time: time ?? this.time,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      repeatDays: repeatDays ?? this.repeatDays,
      ringtone: ringtone ?? this.ringtone,
      vibrate: vibrate ?? this.vibrate,
      focusLabel: focusLabel ?? this.focusLabel,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'time': time.millisecondsSinceEpoch,
        'label': label,
        'enabled': enabled ? 1 : 0,
        'repeat_days': repeatDays.join(','),
        'ringtone': ringtone,
        'vibrate': vibrate ? 1 : 0,
        'focus_label': focusLabel,
      };

  factory Alarm.fromMap(Map<String, dynamic> m) => Alarm(
        id: m['id'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
        label: m['label'] as String? ?? '',
        enabled: (m['enabled'] as int) == 1,
        repeatDays: (m['repeat_days'] as String?)?.isNotEmpty == true
            ? (m['repeat_days'] as String).split(',').map(int.parse).toList()
            : [],
        ringtone: m['ringtone'] as String? ?? 'default',
        vibrate: (m['vibrate'] as int?) == 1,
        focusLabel: m['focus_label'] as String?,
      );

  /// Next fire time from now (accounts for repeat days).
  /// No grace window — if time has passed, it rolls to the next valid day.
  DateTime get nextFireTime {
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    if (repeatDays.isEmpty) {
      // One-shot: if time has already passed, roll to tomorrow
      if (candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    // Repeating: find next matching weekday
    for (var i = 0; i < 7; i++) {
      final check = candidate.add(Duration(days: i));
      final weekday = check.weekday; // 1=Mon..7=Sun
      if (repeatDays.contains(weekday)) {
        if (i == 0 && check.isBefore(now)) continue;
        return check;
      }
    }
    return candidate.add(const Duration(days: 7));
  }
}
