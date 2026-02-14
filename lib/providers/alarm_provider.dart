import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm.dart';
import '../services/database_service.dart';
import '../services/alarm_service.dart';

class AlarmProvider extends ChangeNotifier {
  List<Alarm> _alarms = [];
  List<Alarm> get alarms => _alarms;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _alarms = await DatabaseService.getAlarms();
    _loaded = true;

    // Re-schedule future alarms. Stale one-shots (time already passed today)
    // will be skipped by AlarmScheduler.schedule() since nextFireTime rolls
    // to tomorrow — they won't fire erroneously.
    for (int i = 0; i < _alarms.length; i++) {
      final alarm = _alarms[i];
      if (!alarm.enabled) continue;
      await AlarmScheduler.schedule(alarm);
    }

    notifyListeners();
  }

  Future<Alarm> addAlarm({
    required int hour,
    required int minute,
    String label = '',
    List<int> repeatDays = const [],
    String? focusLabel,
  }) async {
    final alarm = Alarm(
      id: const Uuid().v4(),
      time: DateTime(2000, 1, 1, hour, minute),
      label: label,
      repeatDays: repeatDays,
      focusLabel: focusLabel,
    );
    await DatabaseService.upsertAlarm(alarm);
    await AlarmScheduler.schedule(alarm);
    _alarms.add(alarm);
    _alarms.sort((a, b) => a.nextFireTime.compareTo(b.nextFireTime));
    notifyListeners();
    return alarm;
  }

  Future<void> toggleAlarm(String id) async {
    final idx = _alarms.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final updated = _alarms[idx].copyWith(enabled: !_alarms[idx].enabled);
    _alarms[idx] = updated;
    await DatabaseService.upsertAlarm(updated);
    await AlarmScheduler.schedule(updated);
    notifyListeners();
  }

  Future<void> updateAlarm(Alarm alarm) async {
    final idx = _alarms.indexWhere((a) => a.id == alarm.id);
    if (idx == -1) return;
    _alarms[idx] = alarm;
    await DatabaseService.upsertAlarm(alarm);
    await AlarmScheduler.schedule(alarm);
    _alarms.sort((a, b) => a.nextFireTime.compareTo(b.nextFireTime));
    notifyListeners();
  }

  Future<void> removeAlarm(String id) async {
    final alarm = _alarms.firstWhere((a) => a.id == id);
    await AlarmScheduler.cancel(alarm);
    await DatabaseService.deleteAlarm(id);
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}
