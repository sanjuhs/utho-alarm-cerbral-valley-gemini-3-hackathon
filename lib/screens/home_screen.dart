import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alarm_provider.dart';
import '../providers/task_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/alarm_card.dart';
import '../widgets/task_chip.dart';
import 'alarm_editor_screen.dart';
import 'alarm_history_screen.dart';
import 'settings_screen.dart';
import 'voice_session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _walletBalance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlarmProvider>().load();
      context.read<TaskProvider>().load();
      context.read<PreferencesProvider>().load();
      _loadWallet();
    });
  }

  Future<void> _loadWallet() async {
    final balance = await DatabaseService.getWalletBalance();
    if (mounted) setState(() => _walletBalance = balance);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Utho!',
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: UthoTheme.accent,
                                  letterSpacing: -1,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Consumer<PreferencesProvider>(
                            builder: (_, prefs, __) => Text(
                              '${prefs.prefs.mode.emoji} ${prefs.prefs.mode.displayName} mode',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: UthoTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Wallet chip
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AlarmHistoryScreen()));
                        _loadWallet();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _walletBalance >= 0
                              ? const Color(0xFFFFD700).withAlpha(20)
                              : UthoTheme.danger.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.toll_rounded,
                                size: 14,
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
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.history_rounded,
                          color: UthoTheme.textSecondary),
                      onPressed: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AlarmHistoryScreen()));
                        _loadWallet();
                      },
                      tooltip: 'Activity Log',
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded,
                          color: UthoTheme.textSecondary),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen())),
                    ),
                  ],
                ),
              ),
            ),

            // ── Next Alarm Hero ──
            SliverToBoxAdapter(child: _NextAlarmHero()),

            // ── Today's Focus ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    Text(
                      "Today's Focus",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      onPressed: () => _showAddTaskDialog(context),
                      style: TextButton.styleFrom(foregroundColor: UthoTheme.accent),
                    ),
                  ],
                ),
              ),
            ),
            Consumer<TaskProvider>(
              builder: (_, tasks, __) {
                if (tasks.pendingTasks.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No tasks yet. Add some or let Utho! help you plan.',
                        style: TextStyle(color: UthoTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  );
                }
                return SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: tasks.pendingTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => TaskChip(
                        task: tasks.pendingTasks[i],
                        onComplete: () => tasks.completeTask(tasks.pendingTasks[i].id),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Alarms List ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Text(
                  'Alarms',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            Consumer<AlarmProvider>(
              builder: (_, alarms, __) {
                if (alarms.alarms.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.alarm_add_rounded,
                              size: 64, color: UthoTheme.textSecondary.withAlpha(80)),
                          const SizedBox(height: 12),
                          const Text(
                            'No alarms yet',
                            style: TextStyle(color: UthoTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      child: AlarmCard(
                        alarm: alarms.alarms[i],
                        onToggle: () => alarms.toggleAlarm(alarms.alarms[i].id),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AlarmEditorScreen(alarm: alarms.alarms[i]),
                          ),
                        ),
                        onDismiss: () => alarms.removeAlarm(alarms.alarms[i].id),
                      ),
                    ),
                    childCount: alarms.alarms.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Voice FAB
          FloatingActionButton(
            heroTag: 'voice',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VoiceSessionScreen()),
              );
              _loadWallet();
            },
            backgroundColor: UthoTheme.surfaceElevated,
            child: const Icon(Icons.mic_rounded, color: UthoTheme.accent),
          ),
          const SizedBox(height: 12),
          // Add Alarm FAB
          FloatingActionButton.extended(
            heroTag: 'alarm',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlarmEditorScreen()),
            ),
            icon: const Icon(Icons.alarm_add_rounded),
            label: const Text('Alarm'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: UthoTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Task',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: UthoTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'What do you need to do?',
                hintStyle: const TextStyle(color: UthoTheme.textSecondary),
                filled: true,
                fillColor: UthoTheme.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  context.read<TaskProvider>().addTask(title: val.trim());
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  context.read<TaskProvider>().addTask(title: controller.text.trim());
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: UthoTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextAlarmHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AlarmProvider>(
      builder: (_, alarms, __) {
        final enabled = alarms.alarms.where((a) => a.enabled).toList();
        if (enabled.isEmpty) return const SizedBox.shrink();

        // Nearest alarm
        enabled.sort((a, b) => a.nextFireTime.compareTo(b.nextFireTime));
        final next = enabled.first;

        return Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1E2C), Color(0xFF2A1A35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: UthoTheme.accent.withAlpha(40)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next alarm',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: UthoTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatTimeShort(next.nextFireTime),
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: UthoTheme.textPrimary,
                                letterSpacing: -2,
                              ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatAmPm(next.nextFireTime),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: UthoTheme.accent,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    if (next.label.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(next.label,
                          style: const TextStyle(
                              color: UthoTheme.textSecondary, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: UthoTheme.accent.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'in ${timeUntilAlarm(next.nextFireTime)}',
                      style: const TextStyle(
                        color: UthoTheme.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
