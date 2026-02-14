import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vibration/vibration.dart';
import '../models/alarm.dart';
import '../services/alarm_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import 'voice_session_screen.dart';

/// Full-screen alarm ringing UI with looping audio + vibration.
class AlarmRingingScreen extends StatefulWidget {
  final Alarm alarm;
  const AlarmRingingScreen({super.key, required this.alarm});

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final AudioPlayer _player = AudioPlayer();
  bool _vibrating = true;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startAlarmSound();
    _startVibration();
  }

  Future<void> _startAlarmSound() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setSource(AssetSource('sounds/ring-tone.mp3'));
    await _player.resume();
  }

  Future<void> _startVibration() async {
    if (!widget.alarm.vibrate) return;
    // Vibrate in a pattern until stopped
    while (_vibrating && mounted) {
      final hasVibrator = await Vibration.hasVibrator();
      if (!hasVibrator) break;
      Vibration.vibrate(duration: 800, amplitude: 255);
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  void _stopAlarm() {
    _vibrating = false;
    _player.stop();
    Vibration.cancel();
  }

  void _dismiss() {
    _stopAlarm();
    Navigator.pop(context, 'dismiss');
  }

  void _snooze() async {
    _stopAlarm();
    // Reschedule alarm +5 minutes from now
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    final snoozed = widget.alarm.copyWith(
      time: snoozeTime,
      enabled: true,
    );
    await AlarmScheduler.schedule(snoozed);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snoozed for 5 minutes'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, 'snooze');
    }
  }

  void _talk() {
    _stopAlarm();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VoiceSessionScreen()),
    );
  }

  @override
  void dispose() {
    _stopAlarm();
    _player.dispose();
    WakelockPlus.disable();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: UthoTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Pulsing alarm icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Transform.scale(
                  scale: 1.0 + _pulseController.value * 0.15,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: UthoTheme.accent
                          .withAlpha((40 + _pulseController.value * 60).toInt()),
                    ),
                    child: const Icon(
                      Icons.alarm_rounded,
                      size: 48,
                      color: UthoTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Time
              Text(
                formatTimeShort(now),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                      fontSize: 72,
                    ),
              ),
              Text(
                formatAmPm(now),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: UthoTheme.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),

              // Label
              if (widget.alarm.label.isNotEmpty)
                Text(
                  widget.alarm.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: UthoTheme.textSecondary,
                      ),
                ),
              if (widget.alarm.focusLabel != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: UthoTheme.accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.alarm.focusLabel!,
                    style: const TextStyle(
                      color: UthoTheme.accentLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const Spacer(flex: 3),

              // ── TALK button (hero action) ──
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: _talk,
                  icon: const Icon(Icons.mic_rounded, size: 24),
                  label: const Text('Talk to Utho!',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: UthoTheme.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Snooze + Dismiss row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _snooze,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UthoTheme.textPrimary,
                        side: const BorderSide(color: UthoTheme.textSecondary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Snooze 5m',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _dismiss,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UthoTheme.danger,
                        side: const BorderSide(color: UthoTheme.danger),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Dismiss',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
