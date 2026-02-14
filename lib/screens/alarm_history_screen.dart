import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';

class AlarmHistoryScreen extends StatefulWidget {
  const AlarmHistoryScreen({super.key});

  @override
  State<AlarmHistoryScreen> createState() => _AlarmHistoryScreenState();
}

class _AlarmHistoryScreenState extends State<AlarmHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseService.getAlarmHistory(limit: 100);
    setState(() {
      _history = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UthoTheme.surface,
      appBar: AppBar(title: const Text('Alarm History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded,
                          size: 64,
                          color: UthoTheme.textSecondary.withAlpha(80)),
                      const SizedBox(height: 12),
                      const Text('No alarm history yet',
                          style: TextStyle(color: UthoTheme.textSecondary)),
                      const SizedBox(height: 4),
                      const Text(
                          'Alarms created or deleted by the AI will appear here',
                          style: TextStyle(
                              color: UthoTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (_, i) => _HistoryTile(entry: _history[i]),
                ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final action = entry['action'] as String;
    final label = entry['label'] as String;
    final alarmTime =
        DateTime.fromMillisecondsSinceEpoch(entry['alarm_time'] as int);
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(entry['created_at'] as int);

    final isCreate = action == 'created';
    final icon =
        isCreate ? Icons.alarm_add_rounded : Icons.alarm_off_rounded;
    final color = isCreate ? UthoTheme.accent : UthoTheme.danger;
    final verb = isCreate ? 'Created' : 'Deleted';

    final alarmTimeStr =
        '${alarmTime.hour}:${alarmTime.minute.toString().padLeft(2, '0')}';
    final createdAtStr =
        '${createdAt.day}/${createdAt.month} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: UthoTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$verb: "$label"',
                  style: const TextStyle(
                    color: UthoTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCreate ? 'Set for $alarmTimeStr' : 'Was at $alarmTimeStr',
                  style: const TextStyle(
                      color: UthoTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            createdAtStr,
            style: const TextStyle(
                color: UthoTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
