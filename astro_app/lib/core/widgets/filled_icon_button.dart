import 'package:flutter/material.dart';

/// Boton de icono con fondo solido, legible bajo el tema de la app.
///
/// `IconButton.filled` no sirve aqui: el tema fija `foregroundColor` para
/// todos los IconButton, y ese ajuste global pisa el color propio de la
/// variante. Como el relleno se pinta con `primary` —blanco en oscuro— el
/// icono quedaba blanco sobre blanco, es decir un circulo vacio. Flutter no
/// ofrece un tema por variante, asi que el color correcto se aplica aqui.
class FilledIconButton extends StatelessWidget {
  const FilledIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: onPressed == null
            ? scheme.onSurface.withValues(alpha: 0.12)
            : scheme.primary,
        foregroundColor: onPressed == null
            ? scheme.onSurface.withValues(alpha: 0.38)
            : scheme.onPrimary,
      ),
    );
  }
}
