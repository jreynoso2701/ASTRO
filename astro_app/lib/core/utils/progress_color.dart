import 'dart:ui';

import 'package:astro/core/constants/app_colors.dart';

/// Color de progreso según porcentaje. Usa la paleta semántica: el progreso
/// es un estado, no decoración.
/// - 0-24 %   → rojo — requiere atención
/// - 25-49 %  → interpola de rojo a ámbar
/// - 50-99 %  → interpola de ámbar a verde
/// - 100 %    → verde
Color progressColor(double percent) {
  if (percent >= 100) return AppColors.success;
  if (percent >= 50) {
    final t = (percent - 50) / 50;
    return Color.lerp(AppColors.caution, AppColors.success, t)!;
  }
  if (percent >= 25) {
    final t = (percent - 25) / 25;
    return Color.lerp(AppColors.error, AppColors.caution, t)!;
  }
  // < 25%: rojo — requiere atención
  return AppColors.error;
}
