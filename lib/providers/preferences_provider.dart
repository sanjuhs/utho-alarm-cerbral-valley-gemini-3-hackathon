import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/preferences.dart';
import '../services/database_service.dart';

class PreferencesProvider extends ChangeNotifier {
  UserPreferences _prefs = const UserPreferences();
  UserPreferences get prefs => _prefs;

  String? _apiKey; // OpenAI
  String? get apiKey => _apiKey;

  String? _geminiApiKey;
  String? get geminiApiKey => _geminiApiKey;

  /// Returns the active API key based on selected provider.
  String? get activeApiKey =>
      _prefs.aiProvider == AIProvider.gemini ? _geminiApiKey : _apiKey;

  final _secureStorage = const FlutterSecureStorage();
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _prefs = await DatabaseService.getPreferences();
    _apiKey = await _secureStorage.read(key: 'openai_api_key');
    _geminiApiKey = await _secureStorage.read(key: 'gemini_api_key');
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AssistantMode mode) async {
    _prefs = _prefs.copyWith(mode: mode);
    await DatabaseService.savePreferences(_prefs);
    notifyListeners();
  }

  Future<void> setAIProvider(AIProvider provider) async {
    _prefs = _prefs.copyWith(aiProvider: provider);
    await DatabaseService.savePreferences(_prefs);
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    await _secureStorage.write(key: 'openai_api_key', value: key);
    _prefs = _prefs.copyWith(useBYOK: true);
    await DatabaseService.savePreferences(_prefs);
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    _apiKey = null;
    await _secureStorage.delete(key: 'openai_api_key');
    _prefs = _prefs.copyWith(useBYOK: false);
    await DatabaseService.savePreferences(_prefs);
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String key) async {
    _geminiApiKey = key;
    await _secureStorage.write(key: 'gemini_api_key', value: key);
    notifyListeners();
  }

  Future<void> clearGeminiApiKey() async {
    _geminiApiKey = null;
    await _secureStorage.delete(key: 'gemini_api_key');
    notifyListeners();
  }

  Future<void> setVoiceStyle(String style) async {
    _prefs = _prefs.copyWith(voiceStyle: style);
    await DatabaseService.savePreferences(_prefs);
    notifyListeners();
  }
}
