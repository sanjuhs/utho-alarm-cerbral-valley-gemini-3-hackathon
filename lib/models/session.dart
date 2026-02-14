/// A morning conversation session summary
class Session {
  final String id;
  final DateTime date;
  final String summary; // LLM-generated summary of the morning chat
  final String mode; // 'indian_mom', 'best_friend', 'boss', 'soft'
  final int alarmsCreated;
  final int tasksCreated;

  Session({
    required this.id,
    required this.date,
    this.summary = '',
    this.mode = 'best_friend',
    this.alarmsCreated = 0,
    this.tasksCreated = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'summary': summary,
        'mode': mode,
        'alarms_created': alarmsCreated,
        'tasks_created': tasksCreated,
      };

  factory Session.fromMap(Map<String, dynamic> m) => Session(
        id: m['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        summary: m['summary'] as String? ?? '',
        mode: m['mode'] as String? ?? 'best_friend',
        alarmsCreated: m['alarms_created'] as int? ?? 0,
        tasksCreated: m['tasks_created'] as int? ?? 0,
      );
}
