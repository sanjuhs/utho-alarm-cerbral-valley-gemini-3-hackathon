import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/preferences.dart';
import 'base_voice_service.dart';

/// Gemini Live API via WebSocket + raw PCM audio.
/// Mic: `record` package streams 16kHz mono PCM to Gemini.
/// Speaker: accumulates 24kHz PCM chunks per turn, wraps in WAV, plays via audioplayers.
class GeminiVoiceService extends BaseVoiceService {
  static const _wsHost = 'generativelanguage.googleapis.com';
  static const _wsPath =
      'ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  static const _sendSampleRate = 16000;
  static const _recvSampleRate = 24000;
  static const _model = 'gemini-2.5-flash-preview-native-audio-dialog';

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  bool _connected = false;
  bool _muted = false;

  // Audio playback
  final AudioPlayer _player = AudioPlayer();
  final BytesBuilder _audioBuf = BytesBuilder(copy: false);

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
  bool get isMuted => _muted;

  @override
  void setMuted(bool muted) {
    _muted = muted;
    debugPrint('[Utho/Gemini] Mic ${muted ? "muted" : "unmuted"}');
  }

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
          debugPrint('[Utho/Gemini] Interrupted — flushing audio buffer');
          _audioBuf.clear();
          _player.stop();
          return;
        }
        final modelTurn = sc['modelTurn'] as Map<String, dynamic>?;
        final parts =
            (modelTurn?['parts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final p in parts) {
          if (p.containsKey('text')) {
            _transcriptController.add(p['text'] as String);
          }
          // Accumulate audio PCM chunks
          if (p.containsKey('inlineData')) {
            final inlineData = p['inlineData'] as Map<String, dynamic>;
            final b64 = inlineData['data'] as String?;
            if (b64 != null && b64.isNotEmpty) {
              _audioBuf.add(base64Decode(b64));
            }
          }
        }
        if (sc['turnComplete'] == true) {
          debugPrint('[Utho/Gemini] Turn complete — playing audio (${_audioBuf.length} bytes PCM)');
          _playAccumulatedAudio();
        }
      }
    } catch (e) {
      debugPrint('[Utho/Gemini] Parse error: $e');
    }
  }

  /// Wrap accumulated PCM16 bytes in a WAV header and play via audioplayers.
  Future<void> _playAccumulatedAudio() async {
    final pcmBytes = _audioBuf.takeBytes();
    if (pcmBytes.isEmpty) return;

    final wavBytes = _pcmToWav(pcmBytes, _recvSampleRate, 1, 16);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gemini_reply_${DateTime.now().millisecondsSinceEpoch}.wav');
      await file.writeAsBytes(wavBytes);
      await _player.play(DeviceFileSource(file.path));
      debugPrint('[Utho/Gemini] Playing ${pcmBytes.length} bytes of audio');
    } catch (e) {
      debugPrint('[Utho/Gemini] Audio playback error: $e');
    }
  }

  /// Create a WAV file from raw PCM bytes.
  Uint8List _pcmToWav(Uint8List pcmData, int sampleRate, int channels, int bitsPerSample) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final buf = ByteData(44 + dataSize);
    // RIFF header
    buf.setUint8(0, 0x52); buf.setUint8(1, 0x49); buf.setUint8(2, 0x46); buf.setUint8(3, 0x46); // "RIFF"
    buf.setUint32(4, fileSize, Endian.little);
    buf.setUint8(8, 0x57); buf.setUint8(9, 0x41); buf.setUint8(10, 0x56); buf.setUint8(11, 0x45); // "WAVE"
    // fmt chunk
    buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D); buf.setUint8(14, 0x74); buf.setUint8(15, 0x20); // "fmt "
    buf.setUint32(16, 16, Endian.little); // chunk size
    buf.setUint16(20, 1, Endian.little); // PCM format
    buf.setUint16(22, channels, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, byteRate, Endian.little);
    buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    // data chunk
    buf.setUint8(36, 0x64); buf.setUint8(37, 0x61); buf.setUint8(38, 0x74); buf.setUint8(39, 0x61); // "data"
    buf.setUint32(40, dataSize, Endian.little);
    // PCM data
    for (var i = 0; i < pcmData.length; i++) {
      buf.setUint8(44 + i, pcmData[i]);
    }
    return buf.buffer.asUint8List();
  }

  Future<void> _startMicStreaming() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[Utho/Gemini] No mic permission');
        return;
      }

      final stream = await _recorder.startStream(RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sendSampleRate,
        numChannels: 1,
      ));

      debugPrint('[Utho/Gemini] Mic streaming at ${_sendSampleRate}Hz mono PCM');

      _micSub = stream.listen((Uint8List chunk) {
        if (_ws != null && _connected && chunk.isNotEmpty && !_muted) {
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
    await _player.stop();
  }

  @override
  void dispose() {
    disconnect();
    _recorder.dispose();
    _player.dispose();
    _transcriptController.close();
    _toolCallController.close();
  }
}
