import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:astro/core/constants/app_colors.dart';
import 'package:astro/core/constants/app_typography.dart';

/// Sistema de temas de ASTRO — Dark (default) y Light.
///
/// Lenguaje visual inspirado en las apps de Nike (Training Club / Run Club):
///
/// * **Contraste extremo.** El acento primario es blanco sobre negro (o negro
///   sobre blanco). No hay color de marca en el cromo de la interfaz.
/// * **Superficies planas.** Elevación cero y sin bordes: las tarjetas se
///   distinguen del fondo por un salto sutil de luminancia, no por una línea.
/// * **Botones píldora.** Los botones son cápsulas completamente redondeadas
///   con la etiqueta en MAYÚSCULAS, como el "START" de Nike Run Club.
/// * **El espacio separa.** Los divisores se evitan; el aire hace el trabajo.
abstract final class AppTheme {
  /// Radio de las tarjetas y superficies. Nike usa esquinas suaves pero
  /// discretas: el protagonismo lo tiene la tipografía, no la forma.
  static const double _radiusCard = 14;

  /// Radio de campos de texto y contenedores de entrada.
  static const double _radiusField = 12;

  /// Píldora completa para botones y chips.
  static const BorderRadius _pill = BorderRadius.all(Radius.circular(999));

  /// Relleno de los botones: generoso en vertical para dar peso a la cápsula.
  static const EdgeInsets _buttonPadding = EdgeInsets.symmetric(
    horizontal: 28,
    vertical: 16,
  );

  // ══════════════════════════════════════════════════════════
  //  DARK THEME (default)
  // ══════════════════════════════════════════════════════════

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.accentOnDark,
      onPrimary: AppColors.black,
      primaryContainer: AppColors.darkElevated,
      onPrimaryContainer: AppColors.white,
      secondary: AppColors.grey400,
      onSecondary: AppColors.black,
      surface: AppColors.darkSurface,
      onSurface: AppColors.white,
      surfaceContainerHighest: AppColors.darkElevated,
      onSurfaceVariant: AppColors.grey400,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
      error: AppColors.error,
      onError: AppColors.white,
      tertiary: AppColors.volt,
      onTertiary: AppColors.black,
    );

    return _build(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      background: AppColors.darkBackground,
      card: AppColors.darkCard,
      elevated: AppColors.darkElevated,
      border: AppColors.darkBorder,
      onSurface: AppColors.white,
      onSurfaceMuted: AppColors.grey400,
      accent: AppColors.accentOnDark,
      onAccent: AppColors.black,
      // Sobre fondo oscuro los iconos de las barras del sistema van claros.
      systemOverlay: SystemUiOverlayStyle.light,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  LIGHT THEME
  // ══════════════════════════════════════════════════════════

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.accentOnLight,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.lightElevated,
      onPrimaryContainer: AppColors.accentOnLight,
      secondary: AppColors.grey600,
      onSecondary: AppColors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.accentOnLight,
      surfaceContainerHighest: AppColors.lightElevated,
      onSurfaceVariant: AppColors.grey600,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorder,
      error: AppColors.error,
      onError: AppColors.white,
      tertiary: AppColors.volt,
      onTertiary: AppColors.black,
    );

    return _build(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      background: AppColors.lightBackground,
      card: AppColors.lightCard,
      elevated: AppColors.lightElevated,
      border: AppColors.lightBorder,
      onSurface: AppColors.accentOnLight,
      onSurfaceMuted: AppColors.grey600,
      accent: AppColors.accentOnLight,
      onAccent: AppColors.white,
      systemOverlay: SystemUiOverlayStyle.dark,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  BUILDER COMPARTIDO
  // ══════════════════════════════════════════════════════════

  /// Ambos temas son el mismo diseño con la luminancia invertida, así que se
  /// construyen desde una única definición para que no puedan divergir.
  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color background,
    required Color card,
    required Color elevated,
    required Color border,
    required Color onSurface,
    required Color onSurfaceMuted,
    required Color accent,
    required Color onAccent,
    required SystemUiOverlayStyle systemOverlay,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: _buildTextTheme(onSurface, onSurfaceMuted),

      // ── AppBar ──
      // Transparente y sin sombra: el título se lee como parte del contenido,
      // no como una barra flotando encima.
      appBarTheme: AppBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: AppTypography.titleLarge.copyWith(color: onSurface),
        toolbarTextStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
      ),

      // ── Tarjetas ──
      // Filo de un pixel sobre el fondo. La tarjeta y el lienzo estan a muy
      // pocos tonos de distancia, que es lo que da el aire sobrio de la
      // interfaz; sin el borde los bloques se funden y no se distingue donde
      // termina uno y empieza el siguiente.
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: const BorderRadius.all(Radius.circular(_radiusCard)),
        ),
      ),

      // ── Navegación ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.labelSmall.copyWith(
            color: selected ? onSurface : onSurfaceMuted,
            overflow: TextOverflow.ellipsis,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? onSurface : onSurfaceMuted,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: Colors.transparent,
        elevation: 0,
        selectedIconTheme: IconThemeData(color: onSurface),
        unselectedIconTheme: IconThemeData(color: onSurfaceMuted),
        selectedLabelTextStyle: AppTypography.labelSmall.copyWith(
          color: onSurface,
        ),
        unselectedLabelTextStyle: AppTypography.labelSmall.copyWith(
          color: onSurfaceMuted,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onSurface,
        unselectedLabelColor: onSurfaceMuted,
        labelStyle: AppTypography.labelMedium,
        unselectedLabelStyle: AppTypography.labelMedium,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        // Subrayado grueso al estilo Nike, sin línea divisoria de fondo.
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: onSurface, width: 2.5),
          insets: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),

      // ── Entradas de texto ──
      // Rellenas y sin borde en reposo; el foco se señala con un trazo del
      // color del texto, no con un color de marca.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusField),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusField),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusField),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radiusField),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: onSurfaceMuted),
        hintStyle: AppTypography.bodyMedium.copyWith(color: onSurfaceMuted),
        helperStyle: AppTypography.bodySmall.copyWith(color: onSurfaceMuted),
        prefixIconColor: onSurfaceMuted,
        suffixIconColor: onSurfaceMuted,
      ),

      // ── Botones ──
      // El primario es una píldora de máximo contraste. El resto son
      // variaciones de la misma cápsula.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: elevated,
          disabledForegroundColor: onSurfaceMuted,
          padding: _buttonPadding,
          shape: const RoundedRectangleBorder(borderRadius: _pill),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: elevated,
          disabledForegroundColor: onSurfaceMuted,
          elevation: 0,
          padding: _buttonPadding,
          shape: const RoundedRectangleBorder(borderRadius: _pill),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withValues(alpha: 0.35)),
          padding: _buttonPadding,
          shape: const RoundedRectangleBorder(borderRadius: _pill),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _pill),
          textStyle: AppTypography.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: onSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: _pill),
        extendedTextStyle: AppTypography.labelLarge,
      ),

      // ── Chips ──
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: accent,
        checkmarkColor: onAccent,
        // Sin borde el chip sin seleccionar desaparecia: `card` y el fondo se
        // diferencian por muy poco, sobre todo en oscuro. El contorno le
        // devuelve silueta; el seleccionado no lo necesita porque su relleno
        // ya contrasta.
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: onSurface.withValues(
              alpha: states.contains(WidgetState.selected) ? 0.45 : 0.22,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // Sin estado: los chips de esta familia (ActionChip, Chip) no se
        // seleccionan. Resolverlo por estado no sirve, porque el Chip no
        // propaga `selected` al labelStyle del tema: el texto del chip
        // marcado salia del mismo color que su propio relleno. Los que si se
        // seleccionan son los filtros, y esos fijan sus colores en
        // `AppFilterChip`.
        labelStyle: AppTypography.labelSmall.copyWith(color: onSurface),
        secondaryLabelStyle: AppTypography.labelSmall.copyWith(color: onAccent),
        iconTheme: IconThemeData(size: 18, color: onSurface),
        shape: const RoundedRectangleBorder(borderRadius: _pill),
      ),

      // ── Superficies flotantes ──
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: AppTypography.headlineSmall.copyWith(color: onSurface),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: onSurfaceMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radiusField)),
        ),
        textStyle: AppTypography.bodyMedium.copyWith(color: onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: accent,
        contentTextStyle: AppTypography.labelLarge.copyWith(color: onAccent),
        actionTextColor: onAccent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: _pill),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Divisores ──
      // Casi invisibles a propósito: la separación la da el espacio.
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      // ── Controles ──
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceMuted,
        titleTextStyle: AppTypography.titleMedium.copyWith(color: onSurface),
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: onSurfaceMuted,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(_radiusField)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearMinHeight: 6,
        linearTrackColor: elevated,
        circularTrackColor: elevated,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onAccent : onSurfaceMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : elevated,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(onAccent),
        side: BorderSide(color: onSurfaceMuted, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(accent)),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: elevated,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: accent, borderRadius: _pill),
        textStyle: AppTypography.labelSmall.copyWith(color: onAccent),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  TEXT THEME BUILDER
  // ══════════════════════════════════════════════════════════

  static TextTheme _buildTextTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: onSurface),
      displayMedium: AppTypography.displayMedium.copyWith(color: onSurface),
      displaySmall: AppTypography.displaySmall.copyWith(color: onSurface),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: onSurface),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: onSurface),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: onSurface),
      titleLarge: AppTypography.titleLarge.copyWith(color: onSurface),
      titleMedium: AppTypography.titleMedium.copyWith(color: onSurface),
      titleSmall: AppTypography.titleSmall.copyWith(color: onSurfaceVariant),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: onSurface),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: onSurface),
      bodySmall: AppTypography.bodySmall.copyWith(color: onSurfaceVariant),
      labelLarge: AppTypography.labelLarge.copyWith(color: onSurface),
      labelMedium: AppTypography.labelMedium.copyWith(color: onSurfaceVariant),
      labelSmall: AppTypography.labelSmall.copyWith(color: onSurfaceVariant),
    );
  }
}
