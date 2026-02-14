import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../providers/task_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/voice_service.dart';
import '../utils/theme.dart';

class VoiceSessionScreen extends StatefulWidget {
  /// If non-null, the alarm that triggered this session (ringing screen → talk).
  /// The AI gets full context about which alarm fired and manages follow-ups.
  final Alarm? triggeringAlarm;

  const VoiceSessionScreen({super.key, this.triggeringAlarm});

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen>
    with SingleTickerProviderStateMixin {
  final VoiceService _voice = VoiceService();
  final _transcript = StringBuffer();
  String _status = 'Connecting...';
  bool _connected = false;
  late final AnimationController _waveController;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _toolCallSub;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _startSession();
  }

  Future<void> _startSession() async {
    final prefs = context.read<PreferencesProvider>();
    final tasks = context.read<TaskProvider>();
    final alarmProv = context.read<AlarmProvider>();

    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() => _status = 'Microphone permission required for voice.');
      return;
    }

    // Build rich context for the AI
    final contextBuf = StringBuffer();

    // Triggering alarm context
    final trigger = widget.triggeringAlarm;
    if (trigger != null) {
      contextBuf.writeln('THIS SESSION WAS TRIGGERED BY ALARM:');
      contextBuf.writeln('  Label: "${trigger.label.isNotEmpty ? trigger.label : "Wake up"}"');
      contextBuf.writeln('  Scheduled for: ${trigger.time.hour}:${trigger.time.minute.toString().padLeft(2, '0')}');
      if (trigger.focusLabel != null) {
        contextBuf.writeln('  Focus: ${trigger.focusLabel}');
      }
      contextBuf.writeln('');
    }

    // All existing alarms (so AI knows what's already set)
    final enabledAlarms = alarmProv.alarms.where((a) => a.enabled).toList();
    if (enabledAlarms.isNotEmpty) {
      contextBuf.writeln('ALL CURRENTLY SET ALARMS:');
      for (final a in enabledAlarms) {
        final label = a.label.isNotEmpty ? a.label : 'Alarm';
        final t = '${a.time.hour}:${a.time.minute.toString().padLeft(2, '0')}';
        final ft = '${a.nextFireTime.hour}:${a.nextFireTime.minute.toString().padLeft(2, '0')}';
        contextBuf.writeln('  - "$label" at $t (next fires: $ft) [id: ${a.id}]');
      }
      contextBuf.writeln('');
    } else {
      contextBuf.writeln('NO ALARMS CURRENTLY SET.');
      contextBuf.writeln('');
    }

    // Tasks
    contextBuf.writeln('Tasks: ${tasks.todaySummary}');

    _transcriptSub = _voice.transcriptStream.listen((delta) {
      setState(() => _transcript.write(delta));
    });
    _toolCallSub = _voice.toolCallStream.listen(_handleToolCall);

    try {
      final apiKey = prefs.apiKey;
      if (apiKey == null || apiKey.isEmpty) {
        setState(() => _status = 'No API key set. Go to Settings to add one.');
        return;
      }

      await _voice.connect(
        apiKey: apiKey,
        mode: prefs.prefs.mode,
        todayContext: contextBuf.toString(),
        triggeringAlarmLabel: trigger?.label,
      );
      setState(() {
        _connected = true;
        _status = 'Listening...';
      });
    } catch (e) {
      setState(() => _status = 'Connection failed: $e');
    }
  }

  void _handleToolCall(Map<String, dynamic> call) async {
    final name = call['name'] as String;
    final args = call['arguments'] as Map<String, dynamic>;
    final callId = call['call_id'] as String;

    dynamic result;
    final alarmProv = context.read<AlarmProvider>();
    final taskProv = context.read<TaskProvider>();

    switch (name) {
      case 'create_alarm':
        final alarm = await alarmProv.addAlarm(
          hour: args['hour'] as int,
          minute: args['minute'] as int,
          label: args['label'] as String? ?? '',
          repeatDays: (args['repeat_days'] as List?)?.cast<int>() ?? [],
        );
        result = {
          'status': 'ok',
          'alarm_id': alarm.id,
          'fires_at':
              '${alarm.nextFireTime.hour}:${alarm.nextFireTime.minute.toString().padLeft(2, '0')}',
        };
        break;

      case 'delete_alarm':
        final targetLabel = (args['label'] as String?)?.toLowerCase() ?? '';
        final targetId = args['alarm_id'] as String?;
        final alarms = alarmProv.alarms;
        // Find by exact ID or fuzzy label match
        final match = alarms.cast<dynamic>().firstWhere(
              (a) =>
                  (targetId != null && a.id == targetId) ||
                  (targetLabel.isNotEmpty &&
                      a.label.toLowerCase().contains(targetLabel)),
              orElse: () => null,
            );
        if (match != null) {
          await alarmProv.removeAlarm(match.id);
          result = {'status': 'ok', 'deleted_label': match.label};
        } else {
          result = {
            'status': 'not_found',
            'message': 'No alarm matching "$targetLabel" found'
          };
        }
        break;

      case 'list_alarms':
        result = {
          'alarms': alarmProv.alarms
              .where((a) => a.enabled)
              .map((a) => {
                    'id': a.id,
                    'label': a.label,
                    'time':
                        '${a.time.hour}:${a.time.minute.toString().padLeft(2, '0')}',
                    'fires_at':
                        '${a.nextFireTime.hour}:${a.nextFireTime.minute.toString().padLeft(2, '0')}',
                  })
              .toList(),
        };
        break;

      case 'create_alarm_relative':
        final minutesFromNow = args['minutes_from_now'] as int;
        final futureTime = DateTime.now().add(Duration(minutes: minutesFromNow));
        final relAlarm = await alarmProv.addAlarm(
          hour: futureTime.hour,
          minute: futureTime.minute,
          label: args['label'] as String? ?? '',
        );
        result = {
          'status': 'ok',
          'alarm_id': relAlarm.id,
          'fires_at':
              '${futureTime.hour}:${futureTime.minute.toString().padLeft(2, '0')}',
          'minutes_from_now': minutesFromNow,
        };
        break;

      case 'create_reminder':
        final alarm = await alarmProv.addAlarm(
          hour: args['hour'] as int,
          minute: args['minute'] as int,
          label: args['text'] as String? ?? 'Reminder',
        );
        result = {'status': 'ok', 'reminder_id': alarm.id};
        break;

      case 'add_task':
        DateTime? due;
        if (args['due_hour'] != null) {
          final now = DateTime.now();
          due = DateTime(now.year, now.month, now.day, args['due_hour'] as int,
              args['due_minute'] as int? ?? 0);
        }
        final task = await taskProv.addTask(
          title: args['title'] as String,
          priority: args['priority'] as int? ?? 2,
          dueTime: due,
        );
        result = {'status': 'ok', 'task_id': task.id};
        break;

      case 'list_todays_tasks':
        result = {
          'tasks': taskProv.pendingTasks
              .map((t) => {'title': t.title, 'priority': t.priority})
              .toList(),
        };
        break;

      default:
        result = {'error': 'Unknown tool: $name'};
    }

    _voice.sendToolResult(callId, result);
  }

  @override
  void dispose() {
    _transcriptSub?.cancel();
    _toolCallSub?.cancel();
    _voice.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UthoTheme.surface,
      appBar: AppBar(
        title: const Text('Utho! is listening'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Spacer(),

          // Animated wave / orb
          AnimatedBuilder(
            animation: _waveController,
            builder: (_, __) {
              return Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      UthoTheme.accent
                          .withAlpha(_connected ? 200 : 60),
                      UthoTheme.accent.withAlpha(40),
                      Colors.transparent,
                    ],
                    stops: [
                      0.0,
                      0.5 + _waveController.value * 0.2,
                      1.0,
                    ],
                  ),
                ),
                child: Icon(
                  _connected ? Icons.mic_rounded : Icons.mic_off_rounded,
                  size: 48,
                  color: _connected ? Colors.white : UthoTheme.textSecondary,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Status
          Text(
            _status,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: UthoTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 32),

          // Transcript
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: UthoTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
              ),
              width: double.infinity,
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _transcript.isEmpty
                      ? 'Utho! will speak here...'
                      : _transcript.toString(),
                  style: TextStyle(
                    color: _transcript.isEmpty
                        ? UthoTheme.textSecondary
                        : UthoTheme.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // End session button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('End Session'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: UthoTheme.danger,
                  side: const BorderSide(color: UthoTheme.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
