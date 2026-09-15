import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copia [text] al portapapeles y confirma con un aviso breve.
///
/// Vive aparte del botón para que cualquier gesto (un menú contextual, una
/// pulsación larga) pueda copiar con la misma confirmación.
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  String? label,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(label == null ? 'Copiado' : '$label copiado'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Botón discreto de copiar, pensado para ir junto a un título o una etiqueta
/// de sección sin robarle protagonismo.
class CopyButton extends StatelessWidget {
  const CopyButton({required this.text, this.label, this.size = 18, super.key});

  /// Texto que se copia. Si está vacío el botón no se dibuja.
  final String text;

  /// Nombre de lo copiado, para el aviso: "Descripción copiada".
  final String? label;

  final double size;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final diameter = size + 16;

    // El icono se dibuja, no se toma de la fuente. `Icons.copy_rounded` no
    // llegaba a pintarse en el build web de Docker por mas que el glifo
    // estuviera en el subconjunto compilado y el color fuera el correcto;
    // otros iconos de la misma familia si salian, asi que era ese codepoint.
    // Un trazo propio no depende del tree-shaking ni de que codepoint le
    // toque, y toma el color del tema, que es lo que hace falta.
    //
    // El fondo tampoco es adorno: un icono suelto sobre la tarjeta no se leia
    // como un control, habia que saber que estaba ahi para encontrarlo.
    return Tooltip(
      message: label == null ? 'Copiar' : 'Copiar $label',
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => copyToClipboard(context, text, label: label),
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Center(
              child: CustomPaint(
                size: Size.square(size),
                painter: _CopyGlyphPainter(color: scheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Las dos hojas superpuestas del icono clasico de copiar, trazadas a mano.
///
/// La hoja de atras no se dibuja entera: solo el tramo que la de delante no
/// tapa, que es como se lee la superposicion sin tener que rellenar nada con
/// el color del fondo (que aqui es translucido y no se puede saber).
class _CopyGlyphPainter extends CustomPainter {
  const _CopyGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // Todo el trazado va en fracciones del lado para que escale con `size`.
    double x(double f) => f * s;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = x(0.09)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    // Hoja de delante: abajo a la derecha, cerrada.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x(0.32), x(0.30), x(0.94), x(0.94)),
        Radius.circular(x(0.12)),
      ),
      paint,
    );

    // Hoja de atras: arriba a la izquierda, abierta por donde se solapan.
    final r = Radius.circular(x(0.12));
    final back = Path()
      ..moveTo(x(0.68), x(0.30))
      ..lineTo(x(0.68), x(0.18))
      ..arcToPoint(Offset(x(0.56), x(0.06)), radius: r, clockwise: false)
      ..lineTo(x(0.18), x(0.06))
      ..arcToPoint(Offset(x(0.06), x(0.18)), radius: r, clockwise: false)
      ..lineTo(x(0.06), x(0.58))
      ..arcToPoint(Offset(x(0.18), x(0.70)), radius: r, clockwise: false)
      ..lineTo(x(0.32), x(0.70));
    canvas.drawPath(back, paint);
  }

  @override
  bool shouldRepaint(_CopyGlyphPainter old) => old.color != color;
}

/// Encabezado de un bloque de texto copiable: la etiqueta a la izquierda y el
/// botón de copiar al borde derecho.
class CopyableSectionLabel extends StatelessWidget {
  const CopyableSectionLabel({
    required this.label,
    required this.text,
    this.copyLabel,
    this.style,
    super.key,
  });

  final String label;
  final String text;

  /// Nombre usado en el tooltip y el aviso. Por omisión es [label]; se separa
  /// porque varias secciones se rotulan en mayúsculas y "OBJETIVO copiado" se
  /// lee como un grito.
  final String? copyLabel;

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                style ??
                theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        CopyButton(text: text, label: copyLabel ?? label),
      ],
    );
  }
}

/// Hace copiable un elemento ya compacto tocándolo.
///
/// El badge de folio es el caso típico: es tan pequeño que un botón al lado
/// pesaría más que el dato. El tooltip existe porque, sin él, la acción no se
/// anuncia por ningún lado.
class CopyOnTap extends StatelessWidget {
  const CopyOnTap({
    required this.text,
    required this.child,
    this.label,
    super.key,
  });

  final String text;
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return child;

    return Tooltip(
      message: label == null ? 'Copiar' : 'Copiar $label',
      child: InkWell(
        onTap: () => copyToClipboard(context, text, label: label),
        borderRadius: BorderRadius.circular(4),
        child: child,
      ),
    );
  }
}
