import 'package:flutter/material.dart';

/// Chip de filtro de las pantallas de lista.
///
/// Los colores se fijan aquí y no en `ChipThemeData` a propósito. El tema
/// resuelve `labelStyle` sin el estado `selected`, así que un
/// `WidgetStateTextStyle` caía siempre en la rama de "sin seleccionar": el
/// chip marcado acababa con el texto del mismo color que su propio relleno y
/// desaparecía. Aquí el estado se conoce y el contraste se calcula.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  /// Color propio del filtro (el de un estado, una prioridad…). Cuando falta
  /// se usa el acento del tema.
  final Color? color;

  /// Blanco o negro según el relleno, para que el texto siempre se lea.
  ///
  /// El umbral es 0.179, el punto de WCAG donde el negro empieza a contrastar
  /// mejor que el blanco. Con el 0.5 intuitivo los ámbar y naranjas de
  /// prioridad (#FFA000 está en 0.48) se quedaban con texto blanco encima, que
  /// es el peor de los dos: 2.0:1 frente a 10.4:1 del negro.
  static Color _readableOn(Color fill) =>
      fill.computeLuminance() > 0.179 ? const Color(0xFF111111) : Colors.white;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = selected ? (color ?? scheme.primary) : Colors.transparent;
    final onFill = selected ? _readableOn(fill) : scheme.onSurface;

    return FilterChip(
      // FilterChip reserva 48 px de área táctil aunque mida menos, y las
      // tiras de filtros miden 40: sin esto el chip se desborda y pinta
      // encima del conteo de resultados de la fila siguiente.
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.transparent,
      selectedColor: fill,
      checkmarkColor: onFill,
      // Sin seleccionar el chip no tiene relleno: el contorno es lo único que
      // le da silueta sobre el fondo, así que necesita cuerpo.
      side: BorderSide(
        color: selected ? fill : scheme.onSurface.withValues(alpha: 0.35),
      ),
      labelStyle: TextStyle(
        color: onFill,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
