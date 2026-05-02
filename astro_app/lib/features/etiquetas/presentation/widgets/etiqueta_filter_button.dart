import 'package:flutter/material.dart';
import 'package:astro/core/models/etiqueta.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_chip.dart';

/// Botón compacto que muestra el número de etiquetas activas y abre un
/// Bottom Sheet de selección múltiple con aplicación instantánea.
///
/// Los cambios se propagan vía [onToggle] y [onClear] en tiempo real,
/// por lo que el Kanban / lista reacciona mientras el sheet está abierto.
class EtiquetaFilterButton extends StatelessWidget {
  const EtiquetaFilterButton({
    required this.etiquetas,
    required this.selectedIds,
    required this.onToggle,
    required this.onClear,
    super.key,
  });

  /// Etiquetas disponibles para filtrar (globales + proyecto).
  final List<Etiqueta> etiquetas;

  /// IDs actualmente seleccionados.
  final Set<String> selectedIds;

  /// Llamado al activar/desactivar una etiqueta individual.
  final void Function(String id) onToggle;

  /// Llamado al limpiar todas las selecciones.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = selectedIds.isNotEmpty;
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => _openSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant,
            width: active ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.label_outline, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              active ? 'Etiquetas (${selectedIds.length})' : 'Etiquetas',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EtiquetaFilterSheet(
        etiquetas: etiquetas,
        initialSelectedIds: selectedIds,
        onToggle: onToggle,
        onClear: onClear,
      ),
    );
  }
}

// ── Sheet interno ────────────────────────────────────────

class _EtiquetaFilterSheet extends StatefulWidget {
  const _EtiquetaFilterSheet({
    required this.etiquetas,
    required this.initialSelectedIds,
    required this.onToggle,
    required this.onClear,
  });

  final List<Etiqueta> etiquetas;
  final Set<String> initialSelectedIds;
  final void Function(String id) onToggle;
  final VoidCallback onClear;

  @override
  State<_EtiquetaFilterSheet> createState() => _EtiquetaFilterSheetState();
}

class _EtiquetaFilterSheetState extends State<_EtiquetaFilterSheet> {
  // Copia local para reactividad inmediata en los chips del sheet.
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelectedIds);
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
    widget.onToggle(id); // Propaga al provider → filtrado instantáneo.
  }

  void _clear() {
    setState(() => _selected.clear());
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Header ──
          Row(
            children: [
              const Icon(Icons.label_outline, size: 18),
              const SizedBox(width: 8),
              Text(
                'Filtrar por etiqueta',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_selected.isNotEmpty)
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('Limpiar'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona una o varias (lógica OR — aparecen tarjetas con al menos una etiqueta activa)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),

          // ── Chips ──
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final etiqueta in widget.etiquetas)
                _EtiquetaToggleChip(
                  etiqueta: etiqueta,
                  selected: _selected.contains(etiqueta.id),
                  onTap: () => _toggle(etiqueta.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Chip de toggle con animación ─────────────────────────

class _EtiquetaToggleChip extends StatelessWidget {
  const _EtiquetaToggleChip({
    required this.etiqueta,
    required this.selected,
    required this.onTap,
  });

  final Etiqueta etiqueta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = etiqueta.color;
    final iconData = EtiquetaChip.resolveIcon(etiqueta.icono);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : color.withValues(alpha: 0.07),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono de la etiqueta o círculo de color
            if (iconData != null)
              Icon(iconData, size: 13, color: color)
            else
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            const SizedBox(width: 6),
            Text(
              etiqueta.nombre,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            // Check animado cuando está activo
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Icon(Icons.check_circle, size: 14, color: color),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
