import 'package:flutter/material.dart';
import 'package:astro/core/constants/app_breakpoints.dart';

/// Contenedor adaptativo que limita el ancho del contenido en pantallas
/// grandes para mantener legibilidad. En móvil, ocupa todo el ancho.
///
/// Usar en pantallas de detalle, formularios, y listados que no necesitan
/// layouts multi-columna propios.
class AdaptiveBody extends StatelessWidget {
  const AdaptiveBody({
    required this.child,
    this.maxWidth = 720,
    this.padding,
    super.key,
  });

  /// El contenido a mostrar.
  final Widget child;

  /// Ancho máximo del contenido (default: 720 — óptimo para lectura).
  final double maxWidth;

  /// Padding adicional alrededor del contenido (opcional).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // En móvil (compact), sin restricción de ancho.
    if (width < AppBreakpoints.compact) {
      return padding != null ? Padding(padding: padding!, child: child) : child;
    }

    // En pantallas anchas, centrar con ancho máximo.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Retorna el número de columnas para grids según el ancho disponible.
int adaptiveGridColumns(double width) {
  if (width >= AppBreakpoints.expanded) return 3;
  if (width >= AppBreakpoints.medium) return 2;
  return 1;
}
