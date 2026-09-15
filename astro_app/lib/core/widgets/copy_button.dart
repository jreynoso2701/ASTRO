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

    return IconButton(
      icon: Icon(Icons.copy_rounded, size: size),
      color: scheme.onSurfaceVariant,
      tooltip: label == null ? 'Copiar' : 'Copiar $label',
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: BoxConstraints(minWidth: size + 16, minHeight: size + 16),
      onPressed: () => copyToClipboard(context, text, label: label),
    );
  }
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
