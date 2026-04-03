import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Servicio para reproducir sonidos de notificación in-app.
///
/// Genera un tono corto en memoria (WAV) y lo reproduce con [AudioPlayer].
/// No requiere archivos de audio externos.
class NotificationSoundService {
  NotificationSoundService();

  AudioPlayer? _player;
  Uint8List? _toneBytes;

  /// Reproduce el tono de notificación y vibración háptica.
  Future<void> play() async {
    // Haptic feedback (no-op en web)
    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }

    try {
      _toneBytes ??= _generateNotificationTone();
      _player ??= AudioPlayer();
      await _player!.play(BytesSource(_toneBytes!));
    } catch (_) {
      // Silenciar errores de audio — no bloquear al usuario.
    }
  }

  /// Genera un WAV PCM de ~300 ms con dos tonos descendentes.
  /// Resultado: un sonido limpio estilo "ding-dong" minimalista.
  Uint8List _generateNotificationTone() {
    const sampleRate = 44100;
    const numChannels = 1;
    const bitsPerSample = 16;

    // Dos tonos: 880 Hz (A5) por 150 ms, luego 660 Hz (E5) por 150 ms
    const tone1Freq = 880.0;
    const tone1Duration = 0.15;
    const tone2Freq = 660.0;
    const tone2Duration = 0.15;

    final tone1Samples = (sampleRate * tone1Duration).toInt();
    final tone2Samples = (sampleRate * tone2Duration).toInt();
    final totalSamples = tone1Samples + tone2Samples;

    final dataSize = totalSamples * numChannels * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // ── RIFF header ──
    // "RIFF"
    buffer.setUint8(offset++, 0x52);
    buffer.setUint8(offset++, 0x49);
    buffer.setUint8(offset++, 0x46);
    buffer.setUint8(offset++, 0x46);
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    // "WAVE"
    buffer.setUint8(offset++, 0x57);
    buffer.setUint8(offset++, 0x41);
    buffer.setUint8(offset++, 0x56);
    buffer.setUint8(offset++, 0x45);

    // ── fmt sub-chunk ──
    // "fmt "
    buffer.setUint8(offset++, 0x66);
    buffer.setUint8(offset++, 0x6D);
    buffer.setUint8(offset++, 0x74);
    buffer.setUint8(offset++, 0x20);
    buffer.setUint32(offset, 16, Endian.little); // Subchunk1Size (PCM)
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // AudioFormat (PCM = 1)
    offset += 2;
    buffer.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    buffer.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    buffer.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    buffer.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;

    // ── data sub-chunk ──
    // "data"
    buffer.setUint8(offset++, 0x64);
    buffer.setUint8(offset++, 0x61);
    buffer.setUint8(offset++, 0x74);
    buffer.setUint8(offset++, 0x61);
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // ── PCM samples ──
    const amplitude = 0.35; // Volumen moderado (0.0 – 1.0)
    final maxVal = 32767.0 * amplitude;

    for (var i = 0; i < totalSamples; i++) {
      final double freq;
      final double t;
      final double envelope;

      if (i < tone1Samples) {
        freq = tone1Freq;
        t = i / sampleRate;
        // Fade-in 5ms + fade-out 10ms
        final fadeIn = (i / (sampleRate * 0.005)).clamp(0.0, 1.0);
        final fadeOut = ((tone1Samples - i) / (sampleRate * 0.01)).clamp(
          0.0,
          1.0,
        );
        envelope = fadeIn * fadeOut;
      } else {
        freq = tone2Freq;
        final j = i - tone1Samples;
        t = j / sampleRate;
        final fadeIn = (j / (sampleRate * 0.005)).clamp(0.0, 1.0);
        final fadeOut = ((tone2Samples - j) / (sampleRate * 0.02)).clamp(
          0.0,
          1.0,
        );
        envelope = fadeIn * fadeOut;
      }

      final sample = (sin(2 * pi * freq * t) * maxVal * envelope).toInt();
      buffer.setInt16(offset, sample, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
