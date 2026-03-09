import 'package:flutter/material.dart';

/// Paleta de colores de ASTRO — Inspirada en Nothing Phone.
/// Esquema monocromático con acento rojo.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────
  static const Color nothingRed = Color(0xFFD71921);
  static const Color nothingRedLight = Color(0xFFE84C52);
  static const Color nothingRedDark = Color(0xFFB01018);

  // ── Neutrals (Dark theme base) ─────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF0D0D0D);
  static const Color darkBackground = Color(0xFF111111);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color darkElevated = Color(0xFF222222);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color grey800 = Color(0xFF333333);
  static const Color grey600 = Color(0xFF666666);
  static const Color grey400 = Color(0xFF999999);
  static const Color grey200 = Color(0xFFCCCCCC);
  static const Color white = Color(0xFFFFFFFF);

  // ── Neutrals (Light theme base) ────────────────────────
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFF0F0F0);
  static const Color lightBorder = Color(0xFFE0E0E0);

  // ── Semantic ───────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF2196F3);
}
