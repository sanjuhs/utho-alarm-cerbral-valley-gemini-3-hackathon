class Task {
  final String id;
  final String title;
  final DateTime? dueTime;
  final int priority; // 1=high, 2=med, 3=low
  final String status; // 'pending', 'done', 'skipped'
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.dueTime,
    this.priority = 2,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Task copyWith({
    String? title,
    DateTime? dueTime,
    int? priority,
    String? status,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        dueTime: dueTime ?? this.dueTime,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'due_time': dueTime?.millisecondsSinceEpoch,
        'priority': priority,
        'status': status,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        dueTime: m['due_time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['due_time'] as int)
            : null,
        priority: m['priority'] as int? ?? 2,
        status: m['status'] as String? ?? 'pending',
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
