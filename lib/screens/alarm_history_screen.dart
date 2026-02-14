import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';

class AlarmHistoryScreen extends StatefulWidget {
  const AlarmHistoryScreen({super.key});

  @override
  State<AlarmHistoryScreen> createState() => _AlarmHistoryScreenState();
}

class _AlarmHistoryScreenState extends State<AlarmHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _wallet = [];
  int _balance = 0;
  bool _loading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await DatabaseService.getAlarmHistory(limit: 200);
    final walletRows = await DatabaseService.getWalletHistory(limit: 100);
    final balance = await DatabaseService.getWalletBalance();
    setState(() {
      _history = rows;
      _wallet = walletRows;
      _balance = balance;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UthoTheme.surface,
      appBar: AppBar(
        title: const Text('Activity Log'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: UthoTheme.accent,
          labelColor: UthoTheme.accent,
          unselectedLabelColor: UthoTheme.textSecondary,
          tabs: const [
            Tab(text: 'Alarm Actions'),
            Tab(text: 'Wallet'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryTab(),
                _buildWalletTab(),
              ],
            ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 64, color: UthoTheme.textSecondary.withAlpha(80)),
            const SizedBox(height: 12),
            const Text('No activity yet',
                style: TextStyle(color: UthoTheme.textSecondary)),
            const SizedBox(height: 4),
            const Text(
                'Talk to Utho! and ask it to set alarms.\nAll AI actions will appear here.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: UthoTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (_, i) => _HistoryTile(entry: _history[i]),
    );
  }

  Widget _buildWalletTab() {
    return Column(
      children: [
        // Balance card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _balance >= 0
                  ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)]
                  : [const Color(0xFF2e1a1a), const Color(0xFF3e1621)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _balance >= 0
                  ? const Color(0xFFFFD700).withAlpha(40)
                  : UthoTheme.danger.withAlpha(40),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Utho Coins',
                style: TextStyle(
                  color: UthoTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.toll_rounded,
                      size: 32,
                      color: _balance >= 0
                          ? const Color(0xFFFFD700)
                          : UthoTheme.danger),
                  const SizedBox(width: 8),
                  Text(
                    '₿$_balance',
                    style: TextStyle(
                      color: _balance >= 0
                          ? const Color(0xFFFFD700)
                          : UthoTheme.danger,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _balance >= 100
                    ? 'Crushing it!'
                    : _balance >= 0
                        ? 'Keep going!'
                        : 'Time to focus...',
                style: TextStyle(
                  color: UthoTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Transaction list
        Expanded(
          child: _wallet.isEmpty
              ? Center(
                  child: Text(
                    'No transactions yet.\nYour AI persona will reward or penalize you!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: UthoTheme.textSecondary, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _wallet.length,
                  itemBuilder: (_, i) => _WalletTile(entry: _wallet[i]),
                ),
        ),
      ],
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
    final alarmTime = entry['alarm_time'] != null
        ? DateTime.fromMillisecondsSinceEpoch(entry['alarm_time'] as int)
        : null;
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(entry['created_at'] as int);
    final persona = entry['persona'] as String?;

    IconData icon;
    Color color;
    String verb;

    switch (action) {
      case 'created':
        icon = Icons.alarm_add_rounded;
        color = UthoTheme.accent;
        verb = 'Created';
        break;
      case 'deleted':
        icon = Icons.alarm_off_rounded;
        color = UthoTheme.danger;
        verb = 'Deleted';
        break;
      case 'reward':
        icon = Icons.star_rounded;
        color = const Color(0xFFFFD700);
        verb = 'Reward';
        break;
      case 'penalty':
        icon = Icons.money_off_rounded;
        color = UthoTheme.danger;
        verb = 'Penalty';
        break;
      default:
        icon = Icons.info_rounded;
        color = UthoTheme.textSecondary;
        verb = action;
    }

    final alarmTimeStr = alarmTime != null
        ? '${alarmTime.hour}:${alarmTime.minute.toString().padLeft(2, '0')}'
        : '';
    final createdAtStr =
        '${createdAt.day}/${createdAt.month} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';

    final personaEmoji = switch (persona) {
      'indian_mom' => '🫶',
      'best_friend' => '🔥',
      'boss' => '💼',
      'soft' => '🌙',
      _ => '',
    };

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
                Row(
                  children: [
                    if (alarmTimeStr.isNotEmpty)
                      Text(
                        action == 'created'
                            ? 'Set for $alarmTimeStr'
                            : action == 'deleted'
                                ? 'Was at $alarmTimeStr'
                                : alarmTimeStr,
                        style: const TextStyle(
                            color: UthoTheme.textSecondary, fontSize: 12),
                      ),
                    if (personaEmoji.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(personaEmoji, style: const TextStyle(fontSize: 12)),
                    ],
                  ],
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

class _WalletTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _WalletTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final amount = entry['amount'] as int;
    final reason = entry['reason'] as String;
    final persona = entry['persona'] as String;
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(entry['created_at'] as int);
    final isPositive = amount > 0;

    final personaLabel = switch (persona) {
      'indian_mom' => '🫶 Mom',
      'best_friend' => '🔥 Bestie',
      'boss' => '💼 Boss',
      'soft' => '🌙 Soft',
      _ => persona,
    };

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
            width: 44,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFFFFD700).withAlpha(25)
                  : UthoTheme.danger.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${isPositive ? '+' : ''}$amount',
              style: TextStyle(
                color: isPositive
                    ? const Color(0xFFFFD700)
                    : UthoTheme.danger,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: const TextStyle(
                    color: UthoTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  personaLabel,
                  style: const TextStyle(
                      color: UthoTheme.textSecondary, fontSize: 11),
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
