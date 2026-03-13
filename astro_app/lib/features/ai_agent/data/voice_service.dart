import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Servicio unificado de voz: Speech-to-Text (STT) y Text-to-Speech (TTS).
class VoiceService {
  VoiceService();

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  bool _ttsInitialized = false;
  bool _sttAvailable = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  // ── TTS ──────────────────────────────────────────

  Future<void> initTts() async {
    if (_ttsInitialized) return;

    await _tts.setLanguage('es-MX');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);

    if (!kIsWeb) {
      // En web no se pueden listar engines
      final engines = await _tts.getEngines;
      if (engines != null && engines.isNotEmpty) {
        debugPrint('TTS engines: $engines');
      }
    }

    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS error: $msg');
    });

    _ttsInitialized = true;
  }

  /// Lee un texto en voz alta.
  Future<void> speak(String text) async {
    if (!_ttsInitialized) await initTts();
    // Detener si ya está hablando
    if (_isSpeaking) await stop();
    await _tts.speak(text);
  }

  /// Detiene la reproducción de voz actual.
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  // ── STT ──────────────────────────────────────────

  /// Inicializa el reconocimiento de voz. Retorna `true` si está disponible.
  Future<bool> initStt() async {
    _sttAvailable = await _stt.initialize(
      onError: (error) => debugPrint('STT error: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('STT status: $status'),
    );
    return _sttAvailable;
  }

  /// Indica si STT está disponible en el dispositivo.
  bool get sttAvailable => _sttAvailable;

  /// Indica si está escuchando activamente.
  bool get isListening => _stt.isListening;

  /// Comienza escuchar. Llama a [onResult] con el texto reconocido.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_sttAvailable) {
      final available = await initStt();
      if (!available) return;
    }

    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: 'es_MX',
      listenFor: const Duration(minutes: 2),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  /// Detiene la escucha.
  Future<void> stopListening() async {
    await _stt.stop();
  }

  // ── Cleanup ──────────────────────────────────────

  void dispose() {
    _tts.stop();
    _stt.stop();
  }
}
