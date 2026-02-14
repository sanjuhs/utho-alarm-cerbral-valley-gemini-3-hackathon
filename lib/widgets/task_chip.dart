import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/theme.dart';

class TaskChip extends StatelessWidget {
  final Task task;
  final VoidCallback onComplete;

  const TaskChip({super.key, required this.task, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final colors = [UthoTheme.danger, UthoTheme.accent, UthoTheme.success];
    final color = colors[task.priority - 1];

    return GestureDetector(
      onTap: onComplete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              task.status == 'done'
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                decoration:
                    task.status == 'done' ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
