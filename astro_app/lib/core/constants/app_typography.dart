import 'package:flutter/material.dart';

/// Tipografía de ASTRO.
///
/// Inspirada en las apps de Nike (Training Club / Run Club): titulares muy
/// pesados, en mayúsculas y con tracking negativo, contra un cuerpo de texto
/// neutro y de peso normal. El contraste de peso —no el color— es lo que
/// establece la jerarquía.
///
/// No se empaqueta una fuente propia: se usa la sans del sistema (Roboto en
/// Android, SF Pro en iOS), que en sus pesos altos se acerca mucho a la
/// Helvetica Now de Nike y evita sumar peso al bundle.
abstract final class AppTypography {
  /// Titulares. `null` = sans del sistema.
  static const String? fontFamilyDisplay = null;

  /// Cuerpo de texto. `null` = sans del sistema.
  static const String? fontFamilyBody = null;

  /// Tracking de los titulares en mayúsculas. Nike aprieta mucho las
  /// mayúsculas grandes; cuanto mayor el tamaño, más negativo el tracking.
  static const double _displayTracking = -1.5;

  // ── Display — números y titulares de impacto ──────────
  // Pensados para cifras grandes (avance, contadores, KPIs del dashboard).

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 64,
    fontWeight: FontWeight.w900,
    letterSpacing: _displayTracking * 2,
    height: 1.0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 50,
    fontWeight: FontWeight.w900,
    letterSpacing: _displayTracking * 1.5,
    height: 1.02,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 38,
    fontWeight: FontWeight.w900,
    letterSpacing: _displayTracking,
    height: 1.05,
  );

  // ── Headline — encabezados de pantalla y sección ──────

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 30,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
    height: 1.1,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 25,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.2,
  );

  // ── Title — títulos de tarjeta y AppBar ───────────────

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.35,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.4,
  );

  // ── Body — texto corrido ──────────────────────────────
  // Tracking neutro y line-height generoso: el cuerpo debe leerse tranquilo
  // para que el peso de los titulares destaque por contraste.

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.55,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.45,
  );

  // ── Label — botones, chips y etiquetas de sección ─────
  // Siempre en MAYÚSCULAS con tracking positivo amplio: es la firma de Nike
  // para microcopy y llamadas a la acción.

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.3,
  );

  /// Etiqueta de sección tipo "ENTRENAMIENTOS RECIENTES": diminuta, en
  /// mayúsculas y muy espaciada. Aplícale un color tenue al usarla.
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    height: 1.3,
  );
}
