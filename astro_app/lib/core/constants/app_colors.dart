import 'package:flutter/material.dart';

/// Paleta de colores de ASTRO.
///
/// Lenguaje visual inspirado en las apps de Nike (Training Club / Run Club):
/// contraste extremo entre negro y blanco, superficies planas sin bordes y
/// ausencia total de color de marca en el cromo de la interfaz. El color se
/// reserva exclusivamente para significado (estado, prioridad, alertas), nunca
/// para decorar.
abstract final class AppColors {
  // ── Neutrals (Dark theme base) ─────────────────────────
  // Nike no usa negro puro como fondo de contenido: usa un casi-negro que
  // deja respirar a las tarjetas, con el negro puro reservado para el lienzo.
  static const Color black = Color(0xFF000000);
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF111111);
  static const Color darkCard = Color(0xFF161616);
  static const Color darkElevated = Color(0xFF1F1F1F);

  /// Separador apenas perceptible. En este lenguaje la separación se logra
  /// con espacio en blanco, no con líneas: úsalo solo cuando sea inevitable.
  static const Color darkBorder = Color(0xFF242424);

  // ── Neutrals (Light theme base) ────────────────────────
  // El tema claro invierte la relación: lienzo blanco puro y tarjetas en un
  // gris muy tenue, manteniendo el mismo contraste alto en el texto.
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF5F5F5);
  static const Color lightElevated = Color(0xFFEBEBEB);
  static const Color lightBorder = Color(0xFFE4E4E4);

  // ── Escala de grises ───────────────────────────────────
  static const Color grey900 = Color(0xFF191919);
  static const Color grey800 = Color(0xFF2E2E2E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey400 = Color(0xFFA1A1A1);
  static const Color grey200 = Color(0xFFD6D6D6);

  // ── Acentos de marca ───────────────────────────────────
  /// Acento primario en tema oscuro: blanco puro. Los botones principales son
  /// blancos sobre negro, como el "START" de Nike Run Club.
  static const Color accentOnDark = white;

  /// Acento primario en tema claro: negro puro.
  static const Color accentOnLight = Color(0xFF111111);

  /// Volt — el único color vivo del lenguaje Nike. Uso muy puntual:
  /// progreso alcanzado, logros, resaltar un dato único en pantalla.
  /// No usar como fondo de texto largo ni como color de botón primario.
  static const Color volt = Color(0xFFD7FF3E);

  // ── Semantic ───────────────────────────────────────────
  // Tonos desaturados para que convivan con el alto contraste sin gritar.
  static const Color success = Color(0xFF2FA36B);
  static const Color warning = Color(0xFFE3A008);
  static const Color error = Color(0xFFE5484D);

  /// Escalón intermedio entre `warning` y la normalidad, para semáforos de
  /// tres niveles (p. ej. "vencido / hoy / esta semana").
  static const Color caution = Color(0xFFC9A227);
  static const Color info = Color(0xFF3B82F6);
}
