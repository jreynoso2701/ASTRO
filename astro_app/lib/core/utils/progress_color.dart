import 'dart:ui';

/// Color de progreso según porcentaje (estilo Nothing):
/// - 0-24 %   → rojo (#D71921) — requiere atención
/// - 25-49 %  → interpola de rojo a ámbar
/// - 50-99 %  → interpola de ámbar a verde
/// - 100 %    → verde (#4CAF50)
Color progressColor(double percent) {
  if (percent >= 100) return const Color(0xFF4CAF50);
  if (percent >= 50) {
    final t = (percent - 50) / 50;
    return Color.lerp(const Color(0xFFFFC107), const Color(0xFF4CAF50), t)!;
  }
  if (percent >= 25) {
    final t = (percent - 25) / 25;
    return Color.lerp(const Color(0xFFD71921), const Color(0xFFFFC107), t)!;
  }
  // < 25%: rojo — requiere atención
  return const Color(0xFFD71921);
}
