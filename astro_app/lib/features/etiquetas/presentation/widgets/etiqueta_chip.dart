import 'package:flutter/material.dart';
import 'package:astro/core/models/etiqueta.dart';

/// Chip visual para mostrar una etiqueta en listas, cards y pantallas de detalle.
///
/// Parámetros:
/// - [etiqueta]: la etiqueta a mostrar.
/// - [compact]: si es `true`, muestra solo el color + nombre sin ícono grande.
/// - [onDelete]: si se pasa, muestra botón de eliminar (para formularios).
class EtiquetaChip extends StatelessWidget {
  const EtiquetaChip({
    required this.etiqueta,
    this.compact = false,
    this.onDelete,
    super.key,
  });

  final Etiqueta etiqueta;
  final bool compact;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = etiqueta.color;
    final luminance = color.computeLuminance();
    final textColor = luminance > 0.4 ? Colors.black87 : Colors.white;
    final iconData = resolveIcon(etiqueta.icono);

    if (onDelete != null) {
      // Chip con botón de eliminar (modo formulario)
      return Chip(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: color.withValues(alpha: 0.85),
        side: BorderSide(color: color),
        avatar: iconData != null
            ? Icon(iconData, size: 14, color: textColor)
            : CircleAvatar(backgroundColor: color, radius: 6),
        label: Text(
          etiqueta.nombre,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        deleteIcon: Icon(Icons.close, size: 14, color: textColor),
        onDeleted: onDelete,
      );
    }

    if (compact) {
      // Chip compacto sin ícono de eliminar
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData != null) ...[
              Icon(iconData, size: 12, color: color),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              etiqueta.nombre,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Chip estándar (modo display en listas/detalle)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconData != null) ...[
            Icon(iconData, size: 14, color: color),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            etiqueta.nombre,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          if (etiqueta.esGlobal) ...[
            const SizedBox(width: 4),
            Icon(Icons.public, size: 10, color: color.withValues(alpha: 0.7)),
          ],
        ],
      ),
    );
  }

  /// Resuelve el nombre del ícono en un [IconData].
  static IconData? resolveIcon(String? name) {
    if (name == null || name.isEmpty) return null;
    // Mapeo básico de nombres comunes a IconData.
    const map = <String, IconData>{
      'label': Icons.label,
      'bug_report': Icons.bug_report,
      'code': Icons.code,
      'design_services': Icons.design_services,
      'storage': Icons.storage,
      'cloud': Icons.cloud,
      'phone_android': Icons.phone_android,
      'web': Icons.web,
      'security': Icons.security,
      'speed': Icons.speed,
      'build': Icons.build,
      'star': Icons.star,
      'priority_high': Icons.priority_high,
      'flag': Icons.flag,
      'bookmark': Icons.bookmark,
      'tag': Icons.tag,
      'work': Icons.work,
      'school': Icons.school,
      'science': Icons.science,
      'auto_awesome': Icons.auto_awesome,
    };
    return map[name];
  }
}

/// Widget que muestra un conjunto de etiquetas en fila con wrap.
class EtiquetasRow extends StatelessWidget {
  const EtiquetasRow({
    required this.etiquetas,
    this.compact = false,
    this.maxVisible = 3,
    super.key,
  });

  final List<Etiqueta> etiquetas;
  final bool compact;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (etiquetas.isEmpty) return const SizedBox.shrink();
    final visible = etiquetas.take(maxVisible).toList();
    final overflow = etiquetas.length - maxVisible;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...visible.map((e) => EtiquetaChip(etiqueta: e, compact: compact)),
        if (overflow > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$overflow',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
