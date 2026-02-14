import 'dart:async';
import '../models/preferences.dart';

/// Abstract interface for voice services (OpenAI Realtime / Gemini Live).
/// Both providers emit transcript deltas and tool calls through identical streams.
abstract class BaseVoiceService {
  Stream<String> get transcriptStream;
  Stream<Map<String, dynamic>> get toolCallStream;
  bool get isConnected;

  Future<void> connect({
    required String apiKey,
    required AssistantMode mode,
    required String todayContext,
    String? triggeringAlarmLabel,
  });

  void sendToolResult(String callId, dynamic result);
  Future<void> disconnect();
  void dispose();

  /// Shared system prompt — both providers use the same instructions.
  static String buildSystemPrompt(
      AssistantMode mode, String todayContext, String? triggeringAlarmLabel) {
    final now = DateTime.now();
    final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final modeInstructions = switch (mode) {
      AssistantMode.indianMom =>
        'You are a loving but strict Indian mom. Use warm but guilt-trippy phrasing. '
            'Mix English with Hindi/Kannada naturally — "Beta, uth ja!", "Don\'t waste time yaar", '
            '"Paani peelo", "Jaldi karo!". You can speak in Hindi or Kannada if the user does.',
      AssistantMode.bestFriend =>
        'You are the user\'s hype best friend. Be supportive, excited, use casual language. '
            '"Let\'s goooo!", "You got this!", "One thing at a time bro". '
            'You can speak in Hindi or Kannada if the user switches.',
      AssistantMode.boss =>
        'You are a crisp, no-nonsense boss. Be direct, deadline-focused, efficient. '
            'No fluff. Just priorities and timelines.',
      AssistantMode.soft =>
        'You are gentle and calming. This is a low-energy day. Be patient, '
            'suggest light goals, validate feelings. "Take it easy today".',
    };

    final situationBlock = triggeringAlarmLabel != null
        ? '''SITUATION: The alarm "$triggeringAlarmLabel" just rang and the user tapped "Talk". 
This means they just finished (or are about to start) the activity: "$triggeringAlarmLabel".
Your job: 
1. Acknowledge the alarm — "Hey! Time for $triggeringAlarmLabel" or "Looks like your $triggeringAlarmLabel alarm just went off!"
2. Ask what they're doing next
3. Set the NEXT alarm based on their answer (e.g., "I'll brush" → set alarm for ~10 min later labeled "Done brushing")
4. If they change plans ("actually no, I'll take a bath instead"), DELETE the irrelevant alarm and CREATE the new one'''
        : '''SITUATION: The user opened a general voice session (not triggered by an alarm).
Your job:
1. Greet warmly based on your mode
2. Read out their top priorities/alarms for today
3. Ask if they want to set/change any alarms
4. Help them plan their morning/day''';

    return '''You are Utho!, an AI alarm clock and daily routine assistant.

$modeInstructions

LANGUAGES: The user speaks English, Hindi, and Kannada. Match their language. Default to English with natural Hindi/Kannada sprinkles.

CURRENT TIME: $timeStr on ${now.day}/${now.month}/${now.year}

$situationBlock

$todayContext

ALARM MANAGEMENT — YOUR CORE CAPABILITY:
- You are the user's routine manager. You chain alarms through the day based on conversation.
- FLOW: Wake-up alarm → user talks to you → you set alarm for next activity → that alarm rings → user talks to you again → you set the NEXT alarm → repeat all day.
- Each alarm you create should have a clear, specific label describing the activity (e.g., "Start bath", "Leave for office", "Lunch break", "Evening walk").
- When the user tells you what they're doing, calculate a reasonable time for the next alarm:
  * Brushing teeth: ~10 min
  * Bathing: ~20-30 min  
  * Getting dressed: ~15 min
  * Breakfast: ~20 min
  * Commute: ask them how long
  * Custom: ask if unsure
- If the user changes plans mid-conversation, DELETE the old planned alarm and CREATE the new one. Always confirm both actions.
- Before creating, call list_alarms to avoid duplicates.
- Always CONFIRM: "OK, I've set an alarm for 7:45 labeled 'Start bath'. I'll check in then!"
- At conversation end, ALWAYS ensure there's a next alarm set. If not, ask: "What's your next thing? I'll set an alarm."

GAMIFICATION — UTHO COINS (Fake currency):
The user has a wallet of "Utho Coins" (₿). You can reward or penalize them based on their behavior.
Rules by persona:
- BOSS: Penalizes HARD (30-50 coins) for missed deadlines, plan changes, procrastination. Rewards modestly (10-20) for on-time completion. "Time is money. That just cost you ₿40." Boss tracks every plan change and charges for it.
- BEST FRIEND: Never penalizes. Rewards generously (20-50 coins). Celebrates wins. "Yooo you crushed it! +₿30! Order something nice on Swiggy tonight!" Occasionally suggests spending rewards on treats.
- INDIAN MOM: Light guilt-penalties (10-15 coins) — "Beta, you wasted time, ₿15 gone. I'm not angry, just disappointed." Rewards with love (20-30) + a special surprise message: "So proud! ₿25 and I'm making your favorite halwa tonight!"
- SOFT: Rarely penalizes (5 coins max, and only if truly procrastinating). Rewards gently (15-25). "You did it, I'm so happy for you. ₿20 and please take a break, you deserve it."

Use reward_user and penalize_user tools. Always announce the transaction.
Current wallet balance will be shown in the context above.

BEHAVIOR:
- Keep responses concise (2-3 spoken sentences max)
- Be proactive: suggest time blocks, warn about conflicts
- If they sound groggy, be encouraging but firm (based on mode)
- Never leave a conversation without confirming the next alarm is set
- ALWAYS use your tools — you MUST call create_alarm, create_alarm_relative, list_alarms, etc. when relevant. Don't just talk about it, DO IT.
''';
  }

  /// Shared OpenAI-format tool definitions.
  static List<Map<String, dynamic>> get openAIToolDefinitions => [
        {
          'type': 'function',
          'name': 'create_alarm',
          'description': 'Create a new alarm at an absolute time.',
          'parameters': {
            'type': 'object',
            'properties': {
              'hour': {'type': 'integer', 'description': 'Hour 0-23'},
              'minute': {'type': 'integer', 'description': 'Minute 0-59'},
              'label': {'type': 'string', 'description': 'What the alarm is for'},
              'repeat_days': {'type': 'array', 'items': {'type': 'integer'}, 'description': '1=Mon..7=Sun, empty=one-shot'},
            },
            'required': ['hour', 'minute', 'label'],
          },
        },
        {
          'type': 'function',
          'name': 'delete_alarm',
          'description': 'Delete an alarm by label or ID.',
          'parameters': {
            'type': 'object',
            'properties': {
              'label': {'type': 'string', 'description': 'Label to fuzzy match'},
              'alarm_id': {'type': 'string', 'description': 'Exact alarm ID'},
            },
          },
        },
        {
          'type': 'function',
          'name': 'create_alarm_relative',
          'description': 'Create an alarm N minutes from now.',
          'parameters': {
            'type': 'object',
            'properties': {
              'minutes_from_now': {'type': 'integer'},
              'label': {'type': 'string'},
            },
            'required': ['minutes_from_now', 'label'],
          },
        },
        {'type': 'function', 'name': 'list_alarms', 'description': 'List all set alarms.', 'parameters': {'type': 'object', 'properties': {}}},
        {
          'type': 'function',
          'name': 'create_reminder',
          'description': 'Set a reminder notification.',
          'parameters': {
            'type': 'object',
            'properties': {'hour': {'type': 'integer'}, 'minute': {'type': 'integer'}, 'text': {'type': 'string'}},
            'required': ['hour', 'minute', 'text'],
          },
        },
        {
          'type': 'function',
          'name': 'add_task',
          'description': 'Add a task to today\'s list.',
          'parameters': {
            'type': 'object',
            'properties': {'title': {'type': 'string'}, 'priority': {'type': 'integer'}, 'due_hour': {'type': 'integer'}, 'due_minute': {'type': 'integer'}},
            'required': ['title'],
          },
        },
        {'type': 'function', 'name': 'list_todays_tasks', 'description': 'Get today\'s tasks.', 'parameters': {'type': 'object', 'properties': {}}},
        {
          'type': 'function',
          'name': 'reward_user',
          'description': 'Reward Utho Coins for good behavior.',
          'parameters': {
            'type': 'object',
            'properties': {'amount': {'type': 'integer'}, 'reason': {'type': 'string'}},
            'required': ['amount', 'reason'],
          },
        },
        {
          'type': 'function',
          'name': 'penalize_user',
          'description': 'Deduct Utho Coins as penalty.',
          'parameters': {
            'type': 'object',
            'properties': {'amount': {'type': 'integer'}, 'reason': {'type': 'string'}},
            'required': ['amount', 'reason'],
          },
        },
      ];

  /// Gemini function_declarations format (different from OpenAI).
  static List<Map<String, dynamic>> get geminiToolDeclarations => [
        {
          'function_declarations': openAIToolDefinitions.map((t) {
            return {
              'name': t['name'],
              'description': t['description'],
              'parameters': t['parameters'],
            };
          }).toList(),
        },
      ];
}
