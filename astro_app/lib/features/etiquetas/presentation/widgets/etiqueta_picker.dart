import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/etiqueta.dart';
import 'package:astro/features/etiquetas/providers/etiqueta_providers.dart';
import 'package:astro/features/etiquetas/presentation/widgets/etiqueta_chip.dart';

/// Bottom sheet para seleccionar/quitar etiquetas de un proyecto.
///
/// Uso:
/// ```dart
/// final selected = await EtiquetaPicker.show(
///   context,
///   ref,
///   projectId: projectId,
///   selectedIds: currentIds,
/// );
/// if (selected != null) setState(() => _etiquetaIds = selected);
/// ```
class EtiquetaPicker extends ConsumerStatefulWidget {
  const EtiquetaPicker({
    required this.projectId,
    required this.selectedIds,
    super.key,
  });

  final String projectId;
  final List<String> selectedIds;

  /// Muestra el picker como bottom sheet modal.
  /// Devuelve la nueva lista de IDs seleccionados, o `null` si se canceló.
  static Future<List<String>?> show(
    BuildContext context,
    WidgetRef ref, {
    required String projectId,
    required List<String> selectedIds,
  }) async {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: EtiquetaPicker(
          projectId: projectId,
          selectedIds: List<String>.from(selectedIds),
        ),
      ),
    );
  }

  @override
  ConsumerState<EtiquetaPicker> createState() => _EtiquetaPickerState();
}

class _EtiquetaPickerState extends ConsumerState<EtiquetaPicker> {
  late List<String> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final etiquetasAsync = ref.watch(
      availableEtiquetasProvider(widget.projectId),
    );
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Etiquetas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar etiqueta…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: etiquetasAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (etiquetas) {
                  final filtered = etiquetas
                      .where(
                        (e) =>
                            _search.isEmpty ||
                            e.nombre.toLowerCase().contains(_search),
                      )
                      .toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No hay etiquetas disponibles'),
                    );
                  }
                  // Separar globales y de proyecto
                  final globals = filtered.where((e) => e.esGlobal).toList();
                  final projLabels = filtered
                      .where((e) => !e.esGlobal)
                      .toList();

                  return ListView(
                    controller: scrollController,
                    children: [
                      if (globals.isNotEmpty) ...[
                        _sectionHeader(context, 'GLOBALES'),
                        ...globals.map(
                          (e) => _EtiquetaTile(
                            etiqueta: e,
                            isSelected: _selected.contains(e.id),
                            onTap: () => _toggle(e.id),
                          ),
                        ),
                      ],
                      if (projLabels.isNotEmpty) ...[
                        _sectionHeader(context, 'DEL PROYECTO'),
                        ...projLabels.map(
                          (e) => _EtiquetaTile(
                            etiqueta: e,
                            isSelected: _selected.contains(e.id),
                            onTap: () => _toggle(e.id),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _EtiquetaTile extends StatelessWidget {
  const _EtiquetaTile({
    required this.etiqueta,
    required this.isSelected,
    required this.onTap,
  });

  final Etiqueta etiqueta;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = etiqueta.color;
    return ListTile(
      dense: true,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: EtiquetaChip.resolveIcon(etiqueta.icono) != null
            ? Icon(
                EtiquetaChip.resolveIcon(etiqueta.icono),
                size: 16,
                color: color.computeLuminance() > 0.4
                    ? Colors.black87
                    : Colors.white,
              )
            : null,
      ),
      title: Text(etiqueta.nombre, style: const TextStyle(fontSize: 14)),
      subtitle: etiqueta.esGlobal
          ? Text(
              'Global',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: isSelected
          ? Icon(Icons.check_circle, color: color)
          : Icon(
              Icons.circle_outlined,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
      onTap: onTap,
    );
  }
}
