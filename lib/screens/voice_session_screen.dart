import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../providers/task_provider.dart';
import '../models/preferences.dart';
import '../providers/preferences_provider.dart';
import '../services/base_voice_service.dart';
import '../services/database_service.dart';
import '../services/gemini_voice_service.dart';
import '../services/voice_service.dart';
import '../utils/theme.dart';

/// Represents a single action taken by the AI during the session.
class _ActionEntry {
  final IconData icon;
  final Color color;
  final String text;
  final DateTime time;
  _ActionEntry(this.icon, this.color, this.text) : time = DateTime.now();
}

class VoiceSessionScreen extends StatefulWidget {
  final Alarm? triggeringAlarm;
  const VoiceSessionScreen({super.key, this.triggeringAlarm});

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen>
    with SingleTickerProviderStateMixin {
  late final BaseVoiceService _voice;
  final _transcript = StringBuffer();
  final _actions = <_ActionEntry>[];
  final _sessionId = const Uuid().v4();
  String _status = 'Connecting...';
  bool _connected = false;
  bool _muted = false;
  int _walletBalance = 0;
  late final AnimationController _waveController;
  StreamSubscription? _transcriptSub;
  StreamSubscription? _toolCallSub;

  void _addAction(IconData icon, Color color, String text) {
    setState(() => _actions.add(_ActionEntry(icon, color, text)));
  }

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PreferencesProvider>();
    _voice = prefs.prefs.aiProvider == AIProvider.gemini
        ? GeminiVoiceService()
        : VoiceService();
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

    _walletBalance = await DatabaseService.getWalletBalance();

    final contextBuf = StringBuffer();
    final trigger = widget.triggeringAlarm;
    if (trigger != null) {
      contextBuf.writeln('THIS SESSION WAS TRIGGERED BY ALARM:');
      contextBuf.writeln(
          '  Label: "${trigger.label.isNotEmpty ? trigger.label : "Wake up"}"');
      contextBuf.writeln(
          '  Scheduled for: ${trigger.time.hour}:${trigger.time.minute.toString().padLeft(2, '0')}');
      if (trigger.focusLabel != null) {
        contextBuf.writeln('  Focus: ${trigger.focusLabel}');
      }
      contextBuf.writeln('');
    }

    final enabledAlarms = alarmProv.alarms.where((a) => a.enabled).toList();
    if (enabledAlarms.isNotEmpty) {
      contextBuf.writeln('ALL CURRENTLY SET ALARMS:');
      for (final a in enabledAlarms) {
        final label = a.label.isNotEmpty ? a.label : 'Alarm';
        final t =
            '${a.time.hour}:${a.time.minute.toString().padLeft(2, '0')}';
        final ft =
            '${a.nextFireTime.hour}:${a.nextFireTime.minute.toString().padLeft(2, '0')}';
        contextBuf
            .writeln('  - "$label" at $t (next fires: $ft) [id: ${a.id}]');
      }
      contextBuf.writeln('');
    } else {
      contextBuf.writeln('NO ALARMS CURRENTLY SET.\n');
    }
    contextBuf.writeln('Tasks: ${tasks.todaySummary}');
    contextBuf.writeln('');
    contextBuf.writeln('WALLET BALANCE: $_walletBalance Utho Coins');

    _transcriptSub = _voice.transcriptStream.listen((delta) {
      setState(() => _transcript.write(delta));
    });
    _toolCallSub = _voice.toolCallStream.listen(_handleToolCall);

    try {
      final apiKey = prefs.activeApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        final provider = prefs.prefs.aiProvider.displayName;
        setState(() => _status = 'No $provider API key set. Go to Settings.');
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

  String get _persona => context.read<PreferencesProvider>().prefs.mode.key;

  void _handleToolCall(Map<String, dynamic> call) async {
    final name = call['name'] as String;
    final args = call['arguments'] as Map<String, dynamic>;
    final callId = call['call_id'] as String;

    debugPrint('[Utho] Handling tool call: $name args=$args');

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
        final ft =
            '${alarm.nextFireTime.hour}:${alarm.nextFireTime.minute.toString().padLeft(2, '0')}';
        _addAction(Icons.alarm_add_rounded, UthoTheme.accent,
            '⏰ Alarm set: "${alarm.label}" at $ft');
        await DatabaseService.logAlarmAction(
            'created', alarm.label, alarm.nextFireTime,
            sessionId: _sessionId, persona: _persona);
        result = {'status': 'ok', 'alarm_id': alarm.id, 'fires_at': ft};
        break;

      case 'create_alarm_relative':
        final minutesFromNow = args['minutes_from_now'] as int;
        final futureTime =
            DateTime.now().add(Duration(minutes: minutesFromNow));
        final relAlarm = await alarmProv.addAlarm(
          hour: futureTime.hour,
          minute: futureTime.minute,
          label: args['label'] as String? ?? '',
        );
        final ft =
            '${futureTime.hour}:${futureTime.minute.toString().padLeft(2, '0')}';
        _addAction(Icons.timer_rounded, UthoTheme.accent,
            '⏰ Alarm in ${minutesFromNow}m: "${relAlarm.label}" at $ft');
        await DatabaseService.logAlarmAction(
            'created', relAlarm.label, futureTime,
            sessionId: _sessionId, persona: _persona);
        result = {
          'status': 'ok',
          'alarm_id': relAlarm.id,
          'fires_at': ft,
          'minutes_from_now': minutesFromNow
        };
        break;

      case 'delete_alarm':
        final targetLabel = (args['label'] as String?)?.toLowerCase() ?? '';
        final targetId = args['alarm_id'] as String?;
        final alarms = alarmProv.alarms;
        Alarm? match;
        for (final a in alarms) {
          if (targetId != null && a.id == targetId) { match = a; break; }
          if (targetLabel.isNotEmpty && a.label.toLowerCase().contains(targetLabel)) { match = a; break; }
        }
        if (match != null) {
          await alarmProv.removeAlarm(match.id);
          _addAction(Icons.alarm_off_rounded, UthoTheme.danger,
              '🗑 Deleted: "${match.label}"');
          await DatabaseService.logAlarmAction(
              'deleted', match.label, DateTime.now(),
              sessionId: _sessionId, persona: _persona);
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

      case 'create_reminder':
        final alarm = await alarmProv.addAlarm(
          hour: args['hour'] as int,
          minute: args['minute'] as int,
          label: args['text'] as String? ?? 'Reminder',
        );
        _addAction(Icons.notifications_active_rounded, UthoTheme.accent,
            '🔔 Reminder: "${alarm.label}"');
        await DatabaseService.logAlarmAction(
            'created', alarm.label, alarm.nextFireTime,
            sessionId: _sessionId, persona: _persona);
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
        _addAction(Icons.check_circle_outline_rounded, UthoTheme.accent,
            '✅ Task: "${task.title}"');
        result = {'status': 'ok', 'task_id': task.id};
        break;

      case 'list_todays_tasks':
        result = {
          'tasks': taskProv.pendingTasks
              .map((t) => {'title': t.title, 'priority': t.priority})
              .toList(),
        };
        break;

      case 'reward_user':
        final amount = args['amount'] as int;
        final reason = args['reason'] as String;
        await DatabaseService.addWalletTransaction(amount, reason, _persona);
        _walletBalance += amount;
        _addAction(Icons.star_rounded, const Color(0xFFFFD700),
            '+₿$amount: $reason');
        await DatabaseService.logAlarmAction(
            'reward', '+$amount coins: $reason', DateTime.now(),
            sessionId: _sessionId, persona: _persona);
        result = {'status': 'ok', 'new_balance': _walletBalance};
        break;

      case 'penalize_user':
        final amount = args['amount'] as int;
        final reason = args['reason'] as String;
        await DatabaseService.addWalletTransaction(-amount, reason, _persona);
        _walletBalance -= amount;
        _addAction(Icons.money_off_rounded, UthoTheme.danger,
            '-₿$amount: $reason');
        await DatabaseService.logAlarmAction(
            'penalty', '-$amount coins: $reason', DateTime.now(),
            sessionId: _sessionId, persona: _persona);
        result = {'status': 'ok', 'new_balance': _walletBalance};
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
        title: Consumer<PreferencesProvider>(
          builder: (_, p, __) => Text(
            'Utho! (${p.prefs.aiProvider.displayName})',
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _walletBalance >= 0
                  ? const Color(0xFFFFD700).withAlpha(30)
                  : UthoTheme.danger.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.toll_rounded, size: 16,
                    color: _walletBalance >= 0
                        ? const Color(0xFFFFD700)
                        : UthoTheme.danger),
                const SizedBox(width: 4),
                Text(
                  '₿$_walletBalance',
                  style: TextStyle(
                    color: _walletBalance >= 0
                        ? const Color(0xFFFFD700)
                        : UthoTheme.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Actions strip (shows alarm creates/deletes in real-time) ──
          if (_actions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in _actions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(action.icon, size: 16, color: action.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              action.text,
                              style: TextStyle(
                                color: action.color,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          const Spacer(),

          // Persona avatar with animated glow
          Consumer<PreferencesProvider>(
            builder: (_, prefs, __) {
              final mode = prefs.prefs.mode;
              return AnimatedBuilder(
                animation: _waveController,
                builder: (_, __) {
                  final glowAlpha = _connected
                      ? (100 + (_waveController.value * 100).toInt())
                      : 30;
                  return Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: UthoTheme.accent.withAlpha(glowAlpha),
                          blurRadius: 40 + _waveController.value * 20,
                          spreadRadius: 5 + _waveController.value * 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        mode.imagePath,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                        opacity: AlwaysStoppedAnimation(
                            _connected ? 1.0 : 0.5),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Mode label
          Consumer<PreferencesProvider>(
            builder: (_, prefs, __) => Text(
              '${prefs.prefs.mode.emoji} ${prefs.prefs.mode.displayName}',
              style: const TextStyle(
                color: UthoTheme.accent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 4),

          Text(
            _status,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: UthoTheme.textSecondary),
          ),
          const SizedBox(height: 24),

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
          const SizedBox(height: 12),

          // Mute + End session row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Row(
              children: [
                // Mute button
                if (_connected)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton.filled(
                      onPressed: () {
                        setState(() {
                          _muted = !_muted;
                          _voice.setMuted(_muted);
                          _status = _muted ? 'Mic muted' : 'Listening...';
                        });
                      },
                      icon: Icon(_muted ? Icons.mic_off_rounded : Icons.mic_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: _muted
                            ? UthoTheme.danger.withAlpha(40)
                            : UthoTheme.accent.withAlpha(40),
                        foregroundColor: _muted ? UthoTheme.danger : UthoTheme.accent,
                        padding: const EdgeInsets.all(14),
                      ),
                      tooltip: _muted ? 'Unmute mic' : 'Mute mic',
                    ),
                  ),
                // End session
                Expanded(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
