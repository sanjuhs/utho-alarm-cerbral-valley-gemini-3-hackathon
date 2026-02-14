import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../models/preferences.dart';

/// Manages the OpenAI Realtime API connection via WebRTC.
/// Flow: get ephemeral token → create peer connection → SDP exchange → bidirectional audio.
class VoiceService {
  RTCPeerConnection? _pc;
  RTCDataChannel? _dc;
  MediaStream? _localStream;
  bool _connected = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _toolCallController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<Map<String, dynamic>> get toolCallStream => _toolCallController.stream;
  bool get isConnected => _connected;

  /// Tool definitions the model can invoke
  static List<Map<String, dynamic>> get toolDefinitions => [
        {
          'type': 'function',
          'name': 'create_alarm',
          'description':
              'Create a new alarm. Use this when the user asks to be woken up, reminded, or wants a timer/alarm set for any activity (brushing, bathing, exercise, etc). Always confirm the time back to the user.',
          'parameters': {
            'type': 'object',
            'properties': {
              'hour': {
                'type': 'integer',
                'description': 'Hour in 24h format (0-23)'
              },
              'minute': {
                'type': 'integer',
                'description': 'Minute (0-59)'
              },
              'label': {
                'type': 'string',
                'description':
                    'What the alarm is for — e.g. "Brush teeth", "Start bath", "Leave for office"'
              },
              'repeat_days': {
                'type': 'array',
                'items': {'type': 'integer'},
                'description':
                    'Days to repeat (1=Mon..7=Sun), empty array for one-shot'
              },
            },
            'required': ['hour', 'minute', 'label'],
          },
        },
        {
          'type': 'function',
          'name': 'delete_alarm',
          'description':
              'Delete/cancel an existing alarm by its label or ID. Use when the user says they no longer need an alarm, their plan changed, or they want to cancel something.',
          'parameters': {
            'type': 'object',
            'properties': {
              'label': {
                'type': 'string',
                'description':
                    'Label of the alarm to delete (fuzzy match — closest match wins)'
              },
              'alarm_id': {
                'type': 'string',
                'description': 'Exact alarm ID if known'
              },
            },
          },
        },
        {
          'type': 'function',
          'name': 'create_alarm_relative',
          'description':
              'Create an alarm N minutes from now. Easier than calculating absolute time. '
              'Use when user says "in 10 minutes", "after 30 min", etc.',
          'parameters': {
            'type': 'object',
            'properties': {
              'minutes_from_now': {
                'type': 'integer',
                'description': 'Minutes from now to fire the alarm'
              },
              'label': {
                'type': 'string',
                'description': 'What the alarm is for'
              },
            },
            'required': ['minutes_from_now', 'label'],
          },
        },
        {
          'type': 'function',
          'name': 'list_alarms',
          'description':
              'List all currently set alarms. Use this to check what alarms exist before creating or deleting.',
          'parameters': {'type': 'object', 'properties': {}},
        },
        {
          'type': 'function',
          'name': 'create_reminder',
          'description': 'Set a reminder notification at a specific time',
          'parameters': {
            'type': 'object',
            'properties': {
              'hour': {'type': 'integer'},
              'minute': {'type': 'integer'},
              'text': {'type': 'string', 'description': 'Reminder text'},
            },
            'required': ['hour', 'minute', 'text'],
          },
        },
        {
          'type': 'function',
          'name': 'add_task',
          'description': 'Add a task to today\'s focus list',
          'parameters': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string'},
              'priority': {
                'type': 'integer',
                'description': '1=high, 2=medium, 3=low'
              },
              'due_hour': {'type': 'integer'},
              'due_minute': {'type': 'integer'},
            },
            'required': ['title'],
          },
        },
        {
          'type': 'function',
          'name': 'list_todays_tasks',
          'description': 'Get the user\'s tasks for today',
          'parameters': {'type': 'object', 'properties': {}},
        },
      ];

  /// Start a realtime voice session.
  Future<void> connect({
    String? apiKey,
    String? tokenEndpoint,
    required AssistantMode mode,
    required String todayContext,
    String? triggeringAlarmLabel,
  }) async {
    final token = apiKey ?? await _fetchEphemeralToken(tokenEndpoint!);

    _pc = await createPeerConnection({
      'iceServers': [],
      'sdpSemantics': 'unified-plan',
    });

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
    for (final track in _localStream!.getAudioTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    _dc = await _pc!.createDataChannel(
      'oai-events',
      RTCDataChannelInit()..ordered = true,
    );
    _dc!.onMessage = _handleDataChannelMessage;

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    final model = 'gpt-4o-realtime-preview';
    final sdpResponse = await http.post(
      Uri.parse('https://api.openai.com/v1/realtime?model=$model'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/sdp',
      },
      body: offer.sdp,
    );

    if (sdpResponse.statusCode != 201) {
      throw Exception(
          'Realtime SDP exchange failed: ${sdpResponse.statusCode} ${sdpResponse.body}');
    }

    await _pc!.setRemoteDescription(
      RTCSessionDescription(sdpResponse.body, 'answer'),
    );

    _connected = true;

    _sendEvent({
      'type': 'session.update',
      'session': {
        'instructions':
            _buildSystemPrompt(mode, todayContext, triggeringAlarmLabel),
        'tools': toolDefinitions,
        'voice': 'alloy',
        'input_audio_transcription': {'model': 'whisper-1'},
      },
    });
  }

  String _buildSystemPrompt(
      AssistantMode mode, String todayContext, String? triggeringAlarmLabel) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

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

    // Context-aware opening depends on whether an alarm triggered this session
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

BEHAVIOR:
- Keep responses concise (2-3 spoken sentences max)
- Be proactive: suggest time blocks, warn about conflicts
- If they sound groggy, be encouraging but firm (based on mode)
- Never leave a conversation without confirming the next alarm is set
''';
  }

  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    try {
      final data = jsonDecode(message.text) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'response.audio_transcript.delta') {
        final delta = data['delta'] as String? ?? '';
        _transcriptController.add(delta);
      } else if (type == 'response.function_call_arguments.done') {
        _toolCallController.add({
          'name': data['name'],
          'arguments': jsonDecode(data['arguments'] as String),
          'call_id': data['call_id'],
        });
      }
    } catch (_) {}
  }

  void _sendEvent(Map<String, dynamic> event) {
    if (_dc?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dc!.send(RTCDataChannelMessage(jsonEncode(event)));
    }
  }

  void sendToolResult(String callId, dynamic result) {
    _sendEvent({
      'type': 'conversation.item.create',
      'item': {
        'type': 'function_call_output',
        'call_id': callId,
        'output': jsonEncode(result),
      },
    });
    _sendEvent({'type': 'response.create'});
  }

  Future<String> _fetchEphemeralToken(String endpoint) async {
    final response = await http.post(Uri.parse(endpoint));
    if (response.statusCode != 200) {
      throw Exception('Token fetch failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['client_secret']?['value'] as String? ??
        body['token'] as String;
  }

  Future<void> disconnect() async {
    _connected = false;
    _dc?.close();
    _localStream?.dispose();
    await _pc?.close();
    _pc = null;
    _dc = null;
    _localStream = null;
  }

  void dispose() {
    disconnect();
    _transcriptController.close();
    _toolCallController.close();
  }
}
