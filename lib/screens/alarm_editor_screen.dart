import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';

class AlarmEditorScreen extends StatefulWidget {
  final Alarm? alarm; // null = creating new

  const AlarmEditorScreen({super.key, this.alarm});

  @override
  State<AlarmEditorScreen> createState() => _AlarmEditorScreenState();
}

class _AlarmEditorScreenState extends State<AlarmEditorScreen> {
  late int _hour;
  late int _minute;
  late String _label;
  late List<int> _repeatDays;
  late bool _vibrate;

  bool get isEditing => widget.alarm != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _hour = widget.alarm!.time.hour;
      _minute = widget.alarm!.time.minute;
      _label = widget.alarm!.label;
      _repeatDays = List.of(widget.alarm!.repeatDays);
      _vibrate = widget.alarm!.vibrate;
    } else {
      final now = DateTime.now().add(const Duration(hours: 1));
      _hour = now.hour;
      _minute = 0;
      _label = '';
      _repeatDays = [];
      _vibrate = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Alarm' : 'New Alarm'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: UthoTheme.danger),
              onPressed: () {
                context.read<AlarmProvider>().removeAlarm(widget.alarm!.id);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Time Picker ──
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: UthoTheme.surfaceCard,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_hour > 12 ? _hour - 12 : (_hour == 0 ? 12 : _hour)}:${_minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -3,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hour >= 12 ? 'PM' : 'AM',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: UthoTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Label ──
          TextField(
            controller: TextEditingController(text: _label),
            onChanged: (v) => _label = v,
            style: const TextStyle(color: UthoTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Label',
              labelStyle: const TextStyle(color: UthoTheme.textSecondary),
              filled: true,
              fillColor: UthoTheme.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Repeat Days ──
          Text('Repeat',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = i + 1; // 1=Mon..7=Sun
              final selected = _repeatDays.contains(day);
              const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selected ? _repeatDays.remove(day) : _repeatDays.add(day);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? UthoTheme.accent : UthoTheme.surfaceCard,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selected ? Colors.white : UthoTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            formatDaysList(_repeatDays),
            style: const TextStyle(color: UthoTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // ── Vibrate ──
          SwitchListTile(
            title: const Text('Vibrate'),
            value: _vibrate,
            onChanged: (v) => setState(() => _vibrate = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 32),

          // ── Save ──
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: UthoTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isEditing ? 'Update Alarm' : 'Set Alarm',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (context, child) => Theme(
        data: UthoTheme.dark.copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: UthoTheme.surfaceCard,
            dialHandColor: UthoTheme.accent,
            hourMinuteColor: UthoTheme.surfaceElevated,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  void _save() {
    final provider = context.read<AlarmProvider>();
    if (isEditing) {
      provider.updateAlarm(widget.alarm!.copyWith(
        time: DateTime(2000, 1, 1, _hour, _minute),
        label: _label,
        repeatDays: _repeatDays,
        vibrate: _vibrate,
      ));
    } else {
      provider.addAlarm(
        hour: _hour,
        minute: _minute,
        label: _label,
        repeatDays: _repeatDays,
      );
    }
    Navigator.pop(context);
  }
}
