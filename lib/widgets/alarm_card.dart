import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';

class AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(alarm.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: UthoTheme.danger.withAlpha(40),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: UthoTheme.danger),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: UthoTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: alarm.enabled
                ? Border.all(color: UthoTheme.accent.withAlpha(30))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatTimeShort(alarm.nextFireTime),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.5,
                            color: alarm.enabled
                                ? UthoTheme.textPrimary
                                : UthoTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatAmPm(alarm.nextFireTime),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: alarm.enabled
                                ? UthoTheme.accent
                                : UthoTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (alarm.label.isNotEmpty) alarm.label,
                        formatDaysList(alarm.repeatDays),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: UthoTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: alarm.enabled,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
