import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/preferences.dart';
import 'base_voice_service.dart';

/// Gemini Live API via WebSocket + raw PCM audio.
/// Uses `record` package for mic capture, streams 16kHz mono PCM to Gemini.
class GeminiVoiceService extends BaseVoiceService {
  static const _wsHost = 'generativelanguage.googleapis.com';
  static const _wsPath =
      'ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  static const _sendSampleRate = 16000;
  static const _model = 'gemini-2.5-flash-preview-native-audio-dialog';

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  bool _connected = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _toolCallController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<String> get transcriptStream => _transcriptController.stream;
  @override
  Stream<Map<String, dynamic>> get toolCallStream =>
      _toolCallController.stream;
  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect({
    required String apiKey,
    required AssistantMode mode,
    required String todayContext,
    String? triggeringAlarmLabel,
  }) async {
    final uri = Uri.parse('wss://$_wsHost/$_wsPath?key=$apiKey');
    debugPrint('[Utho/Gemini] Connecting to $_model...');

    _ws = WebSocketChannel.connect(uri);
    await _ws!.ready;
    debugPrint('[Utho/Gemini] WebSocket connected, sending setup...');

    // Send setup message
    final tools = BaseVoiceService.geminiToolDeclarations;
    final setupMsg = jsonEncode({
      'setup': {
        'model': 'models/$_model',
        'generation_config': {
          'response_modalities': ['AUDIO'],
        },
        'tools': tools,
        'system_instruction': {
          'parts': [
            {
              'text': BaseVoiceService.buildSystemPrompt(
                  mode, todayContext, triggeringAlarmLabel),
            },
          ],
        },
      },
    });
    _ws!.sink.add(setupMsg);
    final toolCount = (tools.first['function_declarations'] as List).length;
    debugPrint('[Utho/Gemini] Setup sent with $toolCount tools');

    // Listen for messages
    _wsSub = _ws!.stream.listen(
      _handleMessage,
      onError: (e) {
        debugPrint('[Utho/Gemini] WS error: $e');
        _connected = false;
      },
      onDone: () {
        debugPrint('[Utho/Gemini] WS closed');
        _connected = false;
      },
    );
  }

  void _handleMessage(dynamic raw) {
    try {
      final String text;
      if (raw is Uint8List) {
        text = utf8.decode(raw);
      } else if (raw is List<int>) {
        text = utf8.decode(raw);
      } else {
        text = raw as String;
      }

      final data = jsonDecode(text) as Map<String, dynamic>;

      // Setup complete
      if (data.containsKey('setupComplete')) {
        debugPrint('[Utho/Gemini] Session live! Starting mic...');
        _connected = true;
        _startMicStreaming();
        return;
      }

      // Tool calls
      if (data.containsKey('toolCall')) {
        final toolCall = data['toolCall'] as Map<String, dynamic>;
        final fcs =
            (toolCall['functionCalls'] as List?)?.cast<Map<String, dynamic>>() ??
                [];
        for (final fc in fcs) {
          debugPrint(
              '[Utho/Gemini] Tool call: ${fc['name']} args=${fc['args']}');
          _toolCallController.add({
            'name': fc['name'] as String,
            'arguments': (fc['args'] as Map<String, dynamic>?) ?? {},
            'call_id': fc['id'] as String? ?? '',
          });
        }
        return;
      }

      // Tool call cancellation
      if (data.containsKey('toolCallCancellation')) {
        debugPrint('[Utho/Gemini] Tool call cancelled');
        return;
      }

      // Server content (transcript text + audio)
      if (data.containsKey('serverContent')) {
        final sc = data['serverContent'] as Map<String, dynamic>;
        if (sc['interrupted'] == true) {
          debugPrint('[Utho/Gemini] Interrupted');
          return;
        }
        final modelTurn = sc['modelTurn'] as Map<String, dynamic>?;
        final parts =
            (modelTurn?['parts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final p in parts) {
          if (p.containsKey('text')) {
            _transcriptController.add(p['text'] as String);
          }
          // Audio comes as inlineData — Gemini handles playback via audio output
          // If we wanted local playback, we'd decode the PCM here.
        }
        if (sc['turnComplete'] == true) {
          debugPrint('[Utho/Gemini] Turn complete');
        }
      }
    } catch (e) {
      debugPrint('[Utho/Gemini] Parse error: $e');
    }
  }

  Future<void> _startMicStreaming() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[Utho/Gemini] No mic permission');
        return;
      }

      // Start recording as PCM 16-bit, 16kHz, mono → streamed as Uint8List chunks
      final stream = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sendSampleRate,
        numChannels: 1,
      ));

      debugPrint('[Utho/Gemini] Mic streaming at ${_sendSampleRate}Hz mono PCM');

      _micSub = stream.listen((Uint8List chunk) {
        if (_ws != null && _connected && chunk.isNotEmpty) {
          final b64 = base64Encode(chunk);
          _ws!.sink.add(jsonEncode({
            'realtime_input': {
              'media_chunks': [
                {'data': b64, 'mime_type': 'audio/pcm'},
              ],
            },
          }));
        }
      });
    } catch (e) {
      debugPrint('[Utho/Gemini] Mic error: $e');
    }
  }

  @override
  void sendToolResult(String callId, dynamic result) {
    if (_ws == null) return;
    _ws!.sink.add(jsonEncode({
      'tool_response': {
        'function_responses': [
          {'id': callId, 'response': result},
        ],
      },
    }));
    debugPrint('[Utho/Gemini] Sent tool result for $callId');
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _micSub?.cancel();
    _micSub = null;
    await _recorder.stop();
    await _wsSub?.cancel();
    _wsSub = null;
    await _ws?.sink.close();
    _ws = null;
  }

  @override
  void dispose() {
    disconnect();
    _recorder.dispose();
    _transcriptController.close();
    _toolCallController.close();
  }
}
