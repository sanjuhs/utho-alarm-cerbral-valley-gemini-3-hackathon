import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../services/database_service.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  List<Task> get tasks => _tasks;
  List<Task> get pendingTasks => _tasks.where((t) => t.status == 'pending').toList();
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _tasks = await DatabaseService.getTasks(todayOnly: true);
    _loaded = true;
    notifyListeners();
  }

  Future<Task> addTask({
    required String title,
    int priority = 2,
    DateTime? dueTime,
  }) async {
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      priority: priority,
      dueTime: dueTime,
    );
    await DatabaseService.upsertTask(task);
    _tasks.add(task);
    _tasks.sort((a, b) => a.priority.compareTo(b.priority));
    notifyListeners();
    return task;
  }

  Future<void> completeTask(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = _tasks[idx].copyWith(status: 'done');
    _tasks[idx] = updated;
    await DatabaseService.upsertTask(updated);
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    await DatabaseService.deleteTask(id);
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Generate a text summary of today's tasks for the voice assistant context
  String get todaySummary {
    if (pendingTasks.isEmpty) return 'No tasks set for today yet.';
    final buf = StringBuffer();
    for (var i = 0; i < pendingTasks.length; i++) {
      final t = pendingTasks[i];
      final pri = ['🔴 HIGH', '🟡 MED', '🟢 LOW'][t.priority - 1];
      buf.writeln('${i + 1}. $pri: ${t.title}');
    }
    return buf.toString();
  }
}
