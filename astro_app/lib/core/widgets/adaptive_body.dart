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
    this.maxWidth = readable,
    this.padding,
    super.key,
  });

  /// Ancho de lectura: formularios y pantallas de detalle, donde una linea
  /// larga cansa la vista.
  static const double readable = 720;

  /// Ancho para listados y tableros, que si aprovechan el espacio porque su
  /// contenido se reparte en columnas.
  static const double wide = 1400;

  /// El contenido a mostrar.
  final Widget child;

  /// Ancho máximo del contenido (default: [readable]).
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
  if (width >= AppBreakpoints.large) return 4;
  if (width >= AppBreakpoints.expanded) return 3;
  if (width >= AppBreakpoints.medium) return 2;
  return 1;
}
