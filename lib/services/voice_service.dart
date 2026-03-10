import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

/// Voice service for speech-to-text and text-to-speech
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  
  String _lastRecognized = '';
  String _lastError = '';
  
  // Callbacks
  Function(String)? onResult;
  Function(String)? onError;
  Function(bool)? onListeningStateChanged;
  Function(bool)? onSpeakingStateChanged;

  // Settings
  String _wakeWord = 'open claw';
  List<String> _locales = ['en_US'];
  
  // Continuous mode
  bool _continuousMode = false;
  Timer? _continuousTimer;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get lastRecognized => _lastRecognized;
  String get lastError => _lastError;
  bool get continuousMode => _continuousMode;

  /// Initialize speech recognition and TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize speech recognition
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _lastError = error.errorMsg;
          onError?.call(error.errorMsg);
          _isListening = false;
          onListeningStateChanged?.call(false);
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningStateChanged?.call(false);
            
            // Handle continuous mode restart
            if (_continuousMode && _lastRecognized.isEmpty) {
              startListening();
            }
          }
        },
      );

      if (_isInitialized) {
        // Get available locales
        final locales = await _speech.locales();
        _locales = locales.map((l) => l.localeId).toList();
        
        // Configure TTS
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.5);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);
        
        _tts.setStartHandler(() {
          _isSpeaking = true;
          onSpeakingStateChanged?.call(true);
        });
        
        _tts.setCompletionHandler(() {
          _isSpeaking = false;
          onSpeakingStateChanged?.call(false);
        });
        
        _tts.setErrorHandler((msg) {
          _isSpeaking = false;
          onSpeakingStateChanged?.call(false);
          onError?.call(msg.toString());
        });
      }

      return _isInitialized;
    } catch (e) {
      _lastError = e.toString();
      onError?.call(e.toString());
      return false;
    }
  }

  /// Set the wake word
  void setWakeWord(String word) {
    _wakeWord = word.toLowerCase().trim();
  }

  /// Start listening for speech
  Future<void> startListening({
    String? localeId,
    Duration? listenForDuration,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('Voice service not initialized');
        return;
      }
    }

    if (_isListening) return;

    _lastRecognized = '';
    _lastError = '';
    
    _isListening = true;
    onListeningStateChanged?.call(true);

    await _speech.listen(
      onResult: (result) {
        _lastRecognized = result.recognizedWords;
        onResult?.call(_lastRecognized);
        
        if (result.finalResult) {
          _isListening = false;
          onListeningStateChanged?.call(false);
        }
      },
      listenFor: listenForDuration ?? const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: localeId ?? _locales.first,
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    await _speech.stop();
    _isListening = false;
    _continuousTimer?.cancel();
    _continuousMode = false;
    onListeningStateChanged?.call(false);
  }

  /// Start continuous listening mode
  Future<void> startContinuousListening({
    Duration? interval,
  }) async {
    _continuousMode = true;
    await startListening();
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
    }
    
    await _tts.speak(text);
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    onSpeakingStateChanged?.call(false);
  }

  /// Check if a phrase contains a wake word
  bool containsWakeWord(String phrase) {
    return phrase.toLowerCase().contains(_wakeWord) ||
           phrase.toLowerCase().contains('hey duckbot') ||
           phrase.toLowerCase().contains('duckbot');
  }

  /// Extract command after wake word
  String extractCommand(String phrase) {
    final lower = phrase.toLowerCase();
    
    // Remove wake words
    String command = lower
        .replaceAll(_wakeWord, '')
        .replaceAll('hey duckbot', '')
        .replaceAll('duckbot', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    return command;
  }

  /// Get available locales
  List<String> get availableLocales => _locales;

  /// Set TTS settings
  Future<void> setTtsSettings({
    double? rate,
    double? volume,
    double? pitch,
    String? language,
  }) async {
    if (rate != null) await _tts.setSpeechRate(rate);
    if (volume != null) await _tts.setVolume(volume);
    if (pitch != null) await _tts.setPitch(pitch);
    if (language != null) await _tts.setLanguage(language);
  }

  /// Dispose resources
  Future<void> dispose() async {
    _continuousTimer?.cancel();
    await _speech.stop();
    await _tts.stop();
    _isInitialized = false;
  }
}