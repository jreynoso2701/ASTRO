import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astro/core/models/proyecto.dart';
import 'package:astro/features/dashboard/providers/dashboard_providers.dart';

// ── Filtro de proyectos por pestaña ──────────────────────

/// Chip selector que muestra el estado del filtro de proyectos y abre
/// un bottom sheet para modificarlo.
class DashboardProjectFilterSelector extends ConsumerWidget {
  const DashboardProjectFilterSelector({
    super.key,
    required this.allProjects,
    required this.filterProvider,
  });

  final List<Proyecto> allProjects;
  final NotifierProvider<DashboardTabFilterNotifier, Set<String>> filterProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedIds = ref.watch(filterProvider);
    final isAll = selectedIds.isEmpty;
    final count = isAll ? allProjects.length : selectedIds.length;

    return InkWell(
      onTap: () => showDashboardProjectFilterSheet(
        context,
        allProjects: allProjects,
        filterProvider: filterProvider,
      ),
      borderRadius: BorderRadius.circular(20),
      child: Chip(
        avatar: Icon(
          Icons.folder_outlined,
          size: 16,
          color: isAll
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
        ),
        label: Text(
          isAll
              ? 'Todos los proyectos'
              : '$count proyecto${count == 1 ? '' : 's'}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: isAll
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
        ),
        side: BorderSide(
          color: isAll
              ? theme.colorScheme.outline.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
        backgroundColor: isAll
            ? null
            : theme.colorScheme.primary.withValues(alpha: 0.08),
        deleteIcon: isAll
            ? null
            : Icon(Icons.clear, size: 14, color: theme.colorScheme.primary),
        onDeleted: isAll
            ? null
            : () => ref.read(filterProvider.notifier).selectAll(),
      ),
    );
  }
}

void showDashboardProjectFilterSheet(
  BuildContext context, {
  required List<Proyecto> allProjects,
  required NotifierProvider<DashboardTabFilterNotifier, Set<String>>
  filterProvider,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DashboardProjectFilterSheet(
      allProjects: allProjects,
      filterProvider: filterProvider,
    ),
  );
}

class _DashboardProjectFilterSheet extends ConsumerWidget {
  const _DashboardProjectFilterSheet({
    required this.allProjects,
    required this.filterProvider,
  });

  final List<Proyecto> allProjects;
  final NotifierProvider<DashboardTabFilterNotifier, Set<String>> filterProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedIds = ref.watch(filterProvider);
    final isAll = selectedIds.isEmpty;

    // Proyectos ordenados alfabéticamente
    final sorted = [...allProjects]
      ..sort(
        (a, b) => a.nombreProyecto.toLowerCase().compareTo(
          b.nombreProyecto.toLowerCase(),
        ),
      );

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // ─ Handle ─
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ─ Header ─
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Filtrar proyectos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(filterProvider.notifier).selectAll(),
                  child: Text(
                    'Todos',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ─ Lista con checkboxes ─
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: sorted.length,
              padding: const EdgeInsets.only(bottom: 24),
              itemBuilder: (ctx, i) {
                final p = sorted[i];
                final isSelected = isAll || selectedIds.contains(p.id);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (checked) {
                    if (checked == false && !isAll && selectedIds.length <= 1) {
                      return; // No se puede deseleccionar el último
                    }
                    ref.read(filterProvider.notifier).toggle(p.id, allProjects);
                  },
                  title: Text(
                    p.nombreProyecto,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    p.fkEmpresa,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  secondary: CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                    child: Text(
                      p.folioProyecto.isNotEmpty
                          ? p.folioProyecto.substring(
                              0,
                              p.folioProyecto.length.clamp(0, 2),
                            )
                          : '?',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.trailing,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
