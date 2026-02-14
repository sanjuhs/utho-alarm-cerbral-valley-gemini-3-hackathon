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
        'instructions': _buildSystemPrompt(mode, todayContext),
        'tools': toolDefinitions,
        'voice': 'alloy',
        'input_audio_transcription': {'model': 'whisper-1'},
      },
    });
  }

  String _buildSystemPrompt(AssistantMode mode, String todayContext) {
    final now = DateTime.now();
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

    return '''You are Utho!, an AI alarm clock assistant. You just woke the user up.

$modeInstructions

LANGUAGES: The user speaks English, Hindi, and Kannada. Match their language. Default to English with natural Hindi/Kannada sprinkles.

CURRENT TIME: ${now.hour}:${now.minute.toString().padLeft(2, '0')} on ${now.day}/${now.month}/${now.year}

CONTEXT — Today's schedule and tasks:
$todayContext

ALARM MANAGEMENT — THIS IS CRITICAL:
- You MUST proactively create alarms for the user's next activity at the end of each conversation.
- Example: if user says "I'll brush my teeth now", create an alarm for ~10 minutes later labeled "Done brushing — next activity?"
- If user says "I'll take a bath after this", create an alarm for that.
- If user says their plan changed (e.g., "actually I won't brush, I'll take a bath"), DELETE the old alarm and CREATE the new one.
- Before creating, call list_alarms to check existing alarms and avoid duplicates.
- Always CONFIRM what alarm you set: "Ok, I've set an alarm for 7:15 AM for your bath!"
- Use delete_alarm when the user cancels or changes plans.

BEHAVIOR:
- Greet the user warmly based on your mode
- Read out their top priorities for today
- Keep responses concise (2-3 spoken sentences max)
- Be proactive: suggest time blocks, warn about conflicts
- If they sound groggy, be encouraging but firm (based on mode)
- At the end of the conversation, always ask: "Should I set an alarm for your next thing?"
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
