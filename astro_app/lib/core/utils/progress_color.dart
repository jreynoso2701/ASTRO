import 'dart:ui';

/// Color de progreso según porcentaje:
/// - < 50 %  → rojo (#D71921)
/// - 50 %    → amarillo/ámbar (#FFC107)
/// - > 50 %  → interpola de amarillo a verde
/// - 100 %   → verde (#4CAF50)
Color progressColor(double percent) {
  if (percent >= 100) return const Color(0xFF4CAF50);
  if (percent >= 50) {
    // Interpolar de amarillo (50%) a verde (100%)
    final t = (percent - 50) / 50;
    return Color.lerp(const Color(0xFFFFC107), const Color(0xFF4CAF50), t)!;
  }
  // < 50%: rojo
  return const Color(0xFFD71921);
}
