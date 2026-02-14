import 'dart:async';
import 'dart:collection';
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
/// Speaker: streams 24kHz PCM chunks in ~0.5s segments for near-realtime playback.
class GeminiVoiceService extends BaseVoiceService {
  static const _wsHost = 'generativelanguage.googleapis.com';
  static const _wsPath =
      'ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  static const _sendSampleRate = 16000;
  static const _recvSampleRate = 24000;
  // Models: latest has better quality but intermittent 1008 with tool calling.
  // 09-2025 is more stable per community reports.
  static const _models = [
    'gemini-2.5-flash-native-audio-latest',
    'gemini-2.5-flash-native-audio-preview-12-2025',
    'gemini-2.5-flash-native-audio-preview-09-2025',
  ];
  int _modelIdx = 0;

  // Flush audio every ~0.5s worth of PCM (24kHz * 2 bytes * mono * 0.5s)
  static const _audioFlushThreshold = 24000;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  bool _connected = false;
  bool _muted = false;
  bool _recorderStarted = false;
  bool _disposed = false;

  // Stored params for retry
  String? _lastApiKey;
  AssistantMode? _lastMode;
  String? _lastContext;
  String? _lastTrigger;

  // Audio playback — queue-based streaming
  final BytesBuilder _audioBuf = BytesBuilder(copy: false);
  final Queue<String> _playQueue = Queue();
  AudioPlayer? _currentPlayer;
  bool _isPlaying = false;
  int _wavCounter = 0;
  String? _tempDir;

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
    _disposed = false;
    _lastApiKey = apiKey;
    _lastMode = mode;
    _lastContext = todayContext;
    _lastTrigger = triggeringAlarmLabel;

    final model = _models[_modelIdx];
    final uri = Uri.parse('wss://$_wsHost/$_wsPath?key=$apiKey');
    debugPrint('[Utho/Gemini] Connecting to $model (idx=$_modelIdx)...');

    // Cache temp dir for WAV files
    _tempDir ??= (await getTemporaryDirectory()).path;

    _ws = WebSocketChannel.connect(uri);
    await _ws!.ready;
    debugPrint('[Utho/Gemini] WebSocket connected, sending setup...');

    final tools = BaseVoiceService.geminiToolDeclarations;
    final systemPrompt = BaseVoiceService.buildSystemPrompt(
        mode, todayContext, triggeringAlarmLabel);

    final setupMsg = jsonEncode({
      'setup': {
        'model': 'models/$model',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
        },
        'tools': tools,
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
      },
    });

    _ws!.sink.add(setupMsg);
    final toolCount = (tools.first['function_declarations'] as List).length;
    debugPrint('[Utho/Gemini] Setup sent ($model) with $toolCount tools');

    _wsSub = _ws!.stream.listen(
      _handleMessage,
      onError: (e) {
        debugPrint('[Utho/Gemini] WS error: $e');
        _connected = false;
        _transcriptController.add('\n[Gemini error: $e]');
      },
      onDone: () {
        final code = _ws?.closeCode;
        final reason = _ws?.closeReason;
        debugPrint('[Utho/Gemini] WS closed — code=$code reason=$reason');
        // 1008 = policy violation (known Gemini bug with tool calling)
        // Try next model if available
        if (code == 1008 && _modelIdx < _models.length - 1 && !_disposed) {
          _modelIdx++;
          debugPrint('[Utho/Gemini] Retrying with ${_models[_modelIdx]}...');
          _transcriptController.add('\n[Retrying with ${_models[_modelIdx]}...]');
          _cleanupConnection();
          connect(
            apiKey: _lastApiKey!,
            mode: _lastMode!,
            todayContext: _lastContext!,
            triggeringAlarmLabel: _lastTrigger,
          );
          return;
        }
        if (!_connected) {
          _transcriptController
              .add('\n[Gemini closed: code=$code reason=$reason]');
        }
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
            (toolCall['functionCalls'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
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

      // Server content
      if (data.containsKey('serverContent')) {
        final sc = data['serverContent'] as Map<String, dynamic>;

        if (sc['interrupted'] == true) {
          debugPrint('[Utho/Gemini] Interrupted — flushing');
          _audioBuf.clear();
          _playQueue.clear();
          _stopCurrentPlayer();
          return;
        }

        final modelTurn = sc['modelTurn'] as Map<String, dynamic>?;
        final parts =
            (modelTurn?['parts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        for (final p in parts) {
          if (p.containsKey('text')) {
            _transcriptController.add(p['text'] as String);
          }
          if (p.containsKey('inlineData')) {
            final inlineData = p['inlineData'] as Map<String, dynamic>;
            final b64 = inlineData['data'] as String?;
            if (b64 != null && b64.isNotEmpty) {
              _audioBuf.add(base64Decode(b64));
              // Flush to playback queue when we have enough for ~0.5s
              if (_audioBuf.length >= _audioFlushThreshold) {
                _flushAudioSegment();
              }
            }
          }
        }

        if (sc['turnComplete'] == true || sc['generationComplete'] == true) {
          debugPrint('[Utho/Gemini] Turn complete');
          // Flush any remaining audio
          if (_audioBuf.length > 0) {
            _flushAudioSegment();
          }
        }
      }
    } catch (e) {
      debugPrint('[Utho/Gemini] Parse error: $e');
    }
  }

  /// Take current audio buffer, write as WAV, enqueue for playback.
  void _flushAudioSegment() {
    final pcmBytes = _audioBuf.takeBytes();
    if (pcmBytes.isEmpty || _tempDir == null) return;

    final wavBytes = _pcmToWav(pcmBytes, _recvSampleRate, 1, 16);
    final path = '$_tempDir/gemini_${_wavCounter++}.wav';

    // Write synchronously for minimal latency
    File(path).writeAsBytesSync(wavBytes);
    _playQueue.add(path);

    // Start playing if not already
    if (!_isPlaying) {
      _playNext();
    }
  }

  Future<void> _playNext() async {
    if (_disposed || _playQueue.isEmpty) {
      _isPlaying = false;
      return;
    }

    _isPlaying = true;
    final path = _playQueue.removeFirst();

    try {
      _currentPlayer?.dispose();
      _currentPlayer = AudioPlayer();
      _currentPlayer!.onPlayerComplete.listen((_) {
        // Chain to next segment
        _playNext();
      });
      await _currentPlayer!.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('[Utho/Gemini] Playback error: $e');
      _isPlaying = false;
    }
  }

  void _stopCurrentPlayer() {
    try {
      _currentPlayer?.stop();
      _currentPlayer?.dispose();
    } catch (_) {}
    _currentPlayer = null;
    _isPlaying = false;
  }

  /// Create a WAV file from raw PCM bytes.
  Uint8List _pcmToWav(
      Uint8List pcmData, int sampleRate, int channels, int bitsPerSample) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final buf = ByteData(44 + dataSize);
    buf.setUint8(0, 0x52); buf.setUint8(1, 0x49); buf.setUint8(2, 0x46); buf.setUint8(3, 0x46);
    buf.setUint32(4, fileSize, Endian.little);
    buf.setUint8(8, 0x57); buf.setUint8(9, 0x41); buf.setUint8(10, 0x56); buf.setUint8(11, 0x45);
    buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D); buf.setUint8(14, 0x74); buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, channels, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, byteRate, Endian.little);
    buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    buf.setUint8(36, 0x64); buf.setUint8(37, 0x61); buf.setUint8(38, 0x74); buf.setUint8(39, 0x61);
    buf.setUint32(40, dataSize, Endian.little);
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
      _recorderStarted = true;

      debugPrint('[Utho/Gemini] Mic streaming at ${_sendSampleRate}Hz');

      _micSub = stream.listen((Uint8List chunk) {
        if (_ws != null && _connected && chunk.isNotEmpty && !_muted) {
          _ws!.sink.add(jsonEncode({
            'realtimeInput': {
              'mediaChunks': [
                {'data': base64Encode(chunk), 'mimeType': 'audio/pcm'},
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
      'toolResponse': {
        'functionResponses': [
          {'id': callId, 'response': result},
        ],
      },
    }));
    debugPrint('[Utho/Gemini] Sent tool result for $callId');
  }

  /// Cleanup WS + mic without resetting state (for retry).
  Future<void> _cleanupConnection() async {
    await _micSub?.cancel();
    _micSub = null;
    if (_recorderStarted) {
      try { await _recorder.stop(); } catch (_) {}
      _recorderStarted = false;
    }
    await _wsSub?.cancel();
    _wsSub = null;
    await _ws?.sink.close();
    _ws = null;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _micSub?.cancel();
    _micSub = null;
    if (_recorderStarted) {
      try {
        await _recorder.stop();
      } catch (_) {}
      _recorderStarted = false;
    }
    await _wsSub?.cancel();
    _wsSub = null;
    await _ws?.sink.close();
    _ws = null;
    _stopCurrentPlayer();
    _playQueue.clear();
    _audioBuf.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    _recorder.dispose();
    _transcriptController.close();
    _toolCallController.close();
  }
}
