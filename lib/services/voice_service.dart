import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import '../models/preferences.dart';
import 'base_voice_service.dart';

/// OpenAI Realtime API via WebRTC.
class VoiceService extends BaseVoiceService {
  RTCPeerConnection? _pc;
  RTCDataChannel? _dc;
  MediaStream? _localStream;
  bool _connected = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _toolCallController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _handledCallIds = <String>{};

  @override
  Stream<String> get transcriptStream => _transcriptController.stream;
  @override
  Stream<Map<String, dynamic>> get toolCallStream => _toolCallController.stream;
  @override
  bool get isConnected => _connected;
  bool _muted = false;
  @override
  bool get isMuted => _muted;
  @override
  void setMuted(bool muted) {
    _muted = muted;
    // Mute/unmute the local audio track
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
  }

  static List<Map<String, dynamic>> get toolDefinitions =>
      BaseVoiceService.openAIToolDefinitions;

  @override
  Future<void> connect({
    required String apiKey,
    required AssistantMode mode,
    required String todayContext,
    String? triggeringAlarmLabel,
  }) async {
    final token = apiKey;

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
    
    // Completer to know when DC is open
    final dcOpen = Completer<void>();
    _dc!.onDataChannelState = (state) {
      debugPrint('[Utho] DataChannel state: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen && !dcOpen.isCompleted) {
        dcOpen.complete();
      }
    };

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

    // Wait for data channel to open before sending session config
    debugPrint('[Utho] Waiting for DataChannel to open...');
    await dcOpen.future.timeout(const Duration(seconds: 10), onTimeout: () {
      debugPrint('[Utho] WARNING: DataChannel open timeout — sending anyway');
    });
    debugPrint('[Utho] DataChannel open — sending session.update with ${toolDefinitions.length} tools');

    _sendEvent({
      'type': 'session.update',
      'session': {
        'instructions':
            BaseVoiceService.buildSystemPrompt(mode, todayContext, triggeringAlarmLabel),
        'tools': toolDefinitions,
        'voice': 'alloy',
        'input_audio_transcription': {'model': 'whisper-1'},
      },
    });
  }

  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    try {
      final data = jsonDecode(message.text) as Map<String, dynamic>;
      final type = data['type'] as String?;

      // Transcript deltas
      if (type == 'response.audio_transcript.delta') {
        final delta = data['delta'] as String? ?? '';
        _transcriptController.add(delta);
        return;
      }

      // Function call: arguments streaming done — this is the primary handler
      if (type == 'response.function_call_arguments.done') {
        final callId = data['call_id'] as String?;
        debugPrint('[Utho] Tool call done: ${data['name']} callId=$callId args=${data['arguments']}');
        if (callId != null) _handledCallIds.add(callId);
        _toolCallController.add({
          'name': data['name'],
          'arguments': jsonDecode(data['arguments'] as String),
          'call_id': callId ?? '',
        });
        return;
      }

      // Fallback: output_item.done with function_call type (deduplicated)
      if (type == 'response.output_item.done') {
        final item = data['item'] as Map<String, dynamic>?;
        if (item != null && item['type'] == 'function_call') {
          final callId = item['call_id'] as String?;
          if (callId != null && _handledCallIds.contains(callId)) {
            debugPrint('[Utho] Skipping duplicate output_item.done for callId=$callId');
            return;
          }
          debugPrint('[Utho] Tool call via output_item.done: ${item['name']} args=${item['arguments']}');
          if (callId != null) _handledCallIds.add(callId);
          _toolCallController.add({
            'name': item['name'],
            'arguments': jsonDecode(item['arguments'] as String),
            'call_id': callId ?? '',
          });
          return;
        }
      }

      // Log all non-trivial events for debugging
      if (type != null &&
          !type.contains('audio') &&
          !type.contains('input_audio') &&
          type != 'response.audio.delta' &&
          type != 'response.audio.done') {
        debugPrint('[Utho] DC event: $type');
      }
    } catch (e) {
      debugPrint('[Utho] DC parse error: $e');
    }
  }

  void _sendEvent(Map<String, dynamic> event) {
    if (_dc?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dc!.send(RTCDataChannelMessage(jsonEncode(event)));
    }
  }

  @override
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

  @override
  Future<void> disconnect() async {
    _connected = false;
    _dc?.close();
    _localStream?.dispose();
    await _pc?.close();
    _pc = null;
    _dc = null;
    _localStream = null;
  }

  @override
  void dispose() {
    disconnect();
    _transcriptController.close();
    _toolCallController.close();
  }
}
